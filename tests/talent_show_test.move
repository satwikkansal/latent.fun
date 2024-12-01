#[test_only]
module talent_show_addr::talent_show_tests {
    use std::signer;
    use std::vector;
    use std::string;
    use aptos_framework::coin;
    use aptos_framework::account;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::timestamp;
    use talent_show_addr::talent_show;

    // Test constants
    const REQUIRED_STAKE: u64 = 100;

    // Test helper to setup basic test environment
    fun setup_test(aptos_framework: &signer): (signer, signer, signer, signer) {
        // Create test accounts
        let admin = account::create_account_for_test(@talent_show_addr);
        let performer = account::create_account_for_test(@0x123);
        let judge = account::create_account_for_test(@0x456);
        let audience = account::create_account_for_test(@0x789);

        // Setup initial timestamp
        timestamp::set_time_has_started_for_testing(aptos_framework);

        // Initialize AptosCoin for testing
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<AptosCoin>(
            aptos_framework,
            string::utf8(b"Aptos Coin"),
            string::utf8(b"APT"),
            8,
            false
        );

        // Register and fund accounts with AptosCoin
        coin::register<AptosCoin>(&admin);
        coin::register<AptosCoin>(&performer);
        coin::register<AptosCoin>(&judge);
        coin::register<AptosCoin>(&audience);

        // Mint test coins
        let coins = coin::mint<AptosCoin>(1000, &mint_cap);
        coin::deposit(signer::address_of(&performer), coins);

        let coins = coin::mint<AptosCoin>(1000, &mint_cap);
        coin::deposit(signer::address_of(&audience), coins);

        coin::destroy_burn_cap<AptosCoin>(burn_cap);
        coin::destroy_freeze_cap<AptosCoin>(freeze_cap);
        coin::destroy_mint_cap<AptosCoin>(mint_cap);

        (admin, performer, judge, audience)
    }

    #[test(aptos_framework = @0x1)]
    public fun test_initialize(aptos_framework: &signer) {
        let (admin, _, judge, _) = setup_test(aptos_framework);

        // Create judges list
        let judges = vector::empty<address>();
        vector::push_back(&mut judges, signer::address_of(&judge));

        // Initialize talent show
        talent_show::initialize(&admin, judges);
    }

    #[test(aptos_framework = @0x1)]
    public fun test_submit_performance(aptos_framework: &signer) {
        let (admin, performer, judge, _) = setup_test(aptos_framework);

        // Initialize talent show
        let judges = vector::empty<address>();
        vector::push_back(&mut judges, signer::address_of(&judge));
        talent_show::initialize(&admin, judges);

        // Create stake coins
        let stake = coin::withdraw<AptosCoin>(&performer, REQUIRED_STAKE);

        // Submit performance
        talent_show::submit_performance(
            &performer,
            string::utf8(b"video_link"),
            8, // self score
            stake
        );
    }

    #[test(aptos_framework = @0x1)]
    public fun test_submit_audience_score(aptos_framework: &signer) {
        let (admin, performer, judge, audience) = setup_test(aptos_framework);

        // Initialize talent show
        let judges = vector::empty<address>();
        vector::push_back(&mut judges, signer::address_of(&judge));
        talent_show::initialize(&admin, judges);

        // Submit performance first
        let stake = coin::withdraw<AptosCoin>(&performer, REQUIRED_STAKE);
        talent_show::submit_performance(
            &performer,
            string::utf8(b"video_link"),
            8,
            stake
        );

        // Submit audience score
        let audience_stake = coin::withdraw<AptosCoin>(&audience, REQUIRED_STAKE);
        talent_show::submit_audience_score(
            &audience,
            1, // performance_id
            7,  // score
            audience_stake
        );
    }

    #[test(aptos_framework = @0x1)]
    #[expected_failure(abort_code = talent_show::E_INSUFFICIENT_STAKE)]
    public fun test_insufficient_stake_fails(aptos_framework: &signer) {
        let (admin, performer, judge, _) = setup_test(aptos_framework);

        // Initialize
        let judges = vector::empty<address>();
        vector::push_back(&mut judges, signer::address_of(&judge));
        talent_show::initialize(&admin, judges);

        // Try to submit with insufficient stake
        let stake = coin::withdraw<AptosCoin>(&performer, REQUIRED_STAKE - 1);
        talent_show::submit_performance(
            &performer,
            string::utf8(b"video_link"),
            8,
            stake
        );
    }

    #[test(aptos_framework = @0x1)]
    #[expected_failure(abort_code = talent_show::E_ALREADY_VOTED)]
    public fun test_double_voting_fails(aptos_framework: &signer) {
        let (admin, performer, judge, audience) = setup_test(aptos_framework);

        // Initialize
        let judges = vector::empty<address>();
        vector::push_back(&mut judges, signer::address_of(&judge));
        talent_show::initialize(&admin, judges);

        // Submit performance
        let stake = coin::withdraw<AptosCoin>(&performer, REQUIRED_STAKE);
        talent_show::submit_performance(
            &performer,
            string::utf8(b"video_link"),
            8,
            stake
        );

        // First vote
        let audience_stake = coin::withdraw<AptosCoin>(&audience, REQUIRED_STAKE);
        talent_show::submit_audience_score(
            &audience,
            1,
            7,
            audience_stake
        );

        // Try to vote again
        let audience_stake = coin::withdraw<AptosCoin>(&audience, REQUIRED_STAKE);
        talent_show::submit_audience_score(
            &audience,
            1,
            7,
            audience_stake
        );
    }

    #[test(aptos_framework = @0x1)]
    public fun test_complete_flow(aptos_framework: &signer) {
        let (admin, performer, judge, audience) = setup_test(aptos_framework);

        // Initialize
        let judges = vector::empty<address>();
        vector::push_back(&mut judges, signer::address_of(&judge));
        talent_show::initialize(&admin, judges);

        // Submit performance
        let stake = coin::withdraw<AptosCoin>(&performer, REQUIRED_STAKE);
        talent_show::submit_performance(
            &performer,
            string::utf8(b"video_link"),
            8,
            stake
        );

        // Submit audience score
        let audience_stake = coin::withdraw<AptosCoin>(&audience, REQUIRED_STAKE);
        talent_show::submit_audience_score(
            &audience,
            1,
            8,
            audience_stake
        );

        // Fast forward time
        timestamp::fast_forward_seconds(86401); // voting window + 1

        // Submit judge score
        talent_show::submit_judge_score(&judge, 1, 8);

        // Add small delay to ensure all state changes are processed
        timestamp::fast_forward_seconds(1);

        // Distribute rewards
        talent_show::distribute_rewards(1);
    }
}