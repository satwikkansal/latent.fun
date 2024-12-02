module talent_show_addr::talent_show_v2 {
    use std::string::String;
    use std::vector;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;
    use std::signer;
    use aptos_std::debug;
    use aptos_std::table::{Self, Table};
    use aptos_framework::aptos_coin::AptosCoin;

    /// Error codes
    const E_NOT_INITIALIZED: u64 = 1;
    const E_PERFORMANCE_NOT_EXISTS: u64 = 2;
    const E_ALREADY_VOTED: u64 = 3;
    const E_VOTING_WINDOW_EXPIRED: u64 = 4;
    const E_INSUFFICIENT_STAKE: u64 = 5;
    const E_NOT_JUDGE: u64 = 6;
    const E_VOTING_WINDOW_ACTIVE: u64 = 7;
    const E_ALREADY_CLAIMED: u64 = 8;

    // Constants
    const PLATFORM_FEE_PERCENTAGE: u64 = 5;
    const REQUIRED_STAKE_AMOUNT: u64 = 10; // Fixed stake amount
    const VOTING_WINDOW_DURATION: u64 = 86400; // 24 hours in seconds

    struct Performance has store {
        performer: address,
        video_link: String,
        self_score: u64,
        total_stake: Coin<AptosCoin>,
        judges_scores: vector<u64>,
        audience_scores: Table<address, u64>,
        voting_start_time: u64,
        is_completed: bool,
        pot_claimed: bool,
        judge_votes: vector<JudgeVote>,
    }

    struct TalentShow has key {
        performances: Table<u64, Performance>,
        judges: vector<address>,
        performance_counter: u64,
        platform_balance: Coin<AptosCoin>
    }

    struct JudgeVote has store {
        judge: address,
        score: u64
    }

    // Submit a new performance
public entry fun submit_performance(
    performer: &signer,
    video_link: String,
    self_score: u64,
) acquires TalentShow {
    // Withdraw the stake amount directly in the function
    let stake_amount = coin::withdraw<AptosCoin>(performer, REQUIRED_STAKE_AMOUNT);

    let show = borrow_global_mut<TalentShow>(@talent_show_addr);
    let performance_id = show.performance_counter + 1;

    let performance = Performance {
        performer: signer::address_of(performer),
        video_link,
        self_score,
        total_stake: stake_amount,
        judges_scores: vector::empty(),
        audience_scores: table::new(),
        voting_start_time: timestamp::now_seconds(),
        is_completed: false,
        pot_claimed: false,
        judge_votes: vector::empty()
    };

    table::add(&mut show.performances, performance_id, performance);
    show.performance_counter = performance_id;
}

// Submit audience score
public entry fun submit_audience_score(
    audience: &signer,
    performance_id: u64,
    score: u64,
) acquires TalentShow {
    // Withdraw the stake amount directly in the function
    let stake = coin::withdraw<AptosCoin>(audience, REQUIRED_STAKE_AMOUNT);

    let show = borrow_global_mut<TalentShow>(@talent_show_addr);
    let performance = table::borrow_mut(&mut show.performances, performance_id);

    assert!(!performance.is_completed, E_VOTING_WINDOW_EXPIRED);
    assert!(timestamp::now_seconds() <= performance.voting_start_time + VOTING_WINDOW_DURATION, E_VOTING_WINDOW_EXPIRED);

    let audience_addr = signer::address_of(audience);
    assert!(!table::contains(&performance.audience_scores, audience_addr), E_ALREADY_VOTED);

    table::add(&mut performance.audience_scores, audience_addr, score);
    coin::merge(&mut performance.total_stake, stake);
}

    // Initialize the talent show
    public entry fun initialize(account: &signer, judges: vector<address>) {
        let show = TalentShow {
            performances: table::new(),
            judges: judges,
            performance_counter: 0,
            platform_balance: coin::zero<AptosCoin>()
        };
        move_to(account, show);
    }

    // Helper function to calculate average judge score
    fun calculate_average_score(scores: &vector<u64>): u64 {
        let total = 0u64;
        let i = 0u64;
        let len = vector::length(scores);

        while (i < len) {
            total = total + *vector::borrow(scores, i);
            i = i + 1;
        };

        if (len > 0) {
            total / len
        } else {
            0
        }
    }

    // Distribute rewards
    public entry fun distribute_rewards(performance_id: u64) acquires TalentShow {
        let show = borrow_global_mut<TalentShow>(@talent_show_addr);
        let performance = table::borrow_mut(&mut show.performances, performance_id);

        // Add debug prints to help diagnose the issue
        debug::print(&performance.is_completed);
        debug::print(&vector::length(&performance.judges_scores));
        debug::print(&vector::length(&show.judges));

        assert!(performance.is_completed, E_VOTING_WINDOW_ACTIVE);
        assert!(!performance.pot_claimed, E_ALREADY_CLAIMED);

        let total_stake = coin::value(&performance.total_stake);
        let platform_fee_amount = (total_stake * PLATFORM_FEE_PERCENTAGE) / 100;

        // Extract platform fee
        let platform_fee = coin::extract(&mut performance.total_stake, platform_fee_amount);
        coin::merge(&mut show.platform_balance, platform_fee);

        let judge_avg = calculate_average_score(&performance.judges_scores);

        // Handle performer's correct guess
        if (performance.self_score == judge_avg) {
            let performer_reward = coin::extract(&mut performance.total_stake, total_stake / 2);
            coin::deposit(performance.performer, performer_reward);
        };

        performance.pot_claimed = true;
    }

    public fun get_total_stake(performance_id: u64): u64 acquires TalentShow {
        let show = borrow_global<TalentShow>(@talent_show_addr);
        let performance = table::borrow(&show.performances, performance_id);
        coin::value(&performance.total_stake)
    }

    public entry fun submit_judge_score(
    judge: &signer,
    performance_id: u64,
    score: u64
) acquires TalentShow {
    let show = borrow_global_mut<TalentShow>(@talent_show_addr);
    let judge_addr = signer::address_of(judge);
    assert!(vector::contains(&show.judges, &judge_addr), E_NOT_JUDGE);

    let performance = table::borrow_mut(&mut show.performances, performance_id);
    assert!(timestamp::now_seconds() > performance.voting_start_time + VOTING_WINDOW_DURATION, E_VOTING_WINDOW_ACTIVE);

    // Check if judge has already voted
    let i = 0;
    let has_voted = false;
    while (i < vector::length(&performance.judge_votes)) {
        let vote = vector::borrow(&performance.judge_votes, i);
        if (vote.judge == judge_addr) {
            has_voted = true;
            break
        };
        i = i + 1;
    };
    assert!(!has_voted, E_ALREADY_VOTED);

    // Record the judge's vote
    vector::push_back(&mut performance.judges_scores, score);
    vector::push_back(&mut performance.judge_votes, JudgeVote { judge: judge_addr, score });

    // Mark as completed if all judges have voted
    if (vector::length(&performance.judges_scores) == vector::length(&show.judges)) {
        performance.is_completed = true;
    };
}

public fun get_performance_status(id: u64): bool acquires TalentShow {
    let show = borrow_global<TalentShow>(@talent_show_addr);
    let performance = table::borrow(&show.performances, id);
    performance.is_completed
}
}