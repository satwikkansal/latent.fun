# latent.fun

Backend code for latent.fun project

Aptos tesnet module: `0x1fd2ada641c9711e2bd7a9fb0ddd5ea2f535d8331eff349ad788af51488c31bc::talent_show_v2`
Base sepolia contract address: `0x6D05ab9977aeE3890854A17e0Da20a57aB3Ef555`

Both EVM and Aptos contracts contain end-to-end unit tests that can be run.

## EVM

```angular2html
 TalentShow
    Initialization
      ✔ Should set the correct judges (67ms)
      ✔ Should set the correct owner
    Performance Submission
      ✔ Should allow performance submission with correct stake (2447ms)
      ✔ Should reject performance submission with incorrect stake (39ms)
    Audience Voting
      ✔ Should allow audience voting with correct stake (1267ms)
      ✔ Should prevent double voting by audience (1053ms)
    Judge Voting
      ✔ Should allow judges to vote after voting window (1217ms)
      ✔ Should prevent non-judges from voting (718ms)
    Reward Distribution
      ✔ Should distribute rewards correctly when performer guesses correctly (1088ms)
      ✔ Should prevent double reward distribution (784ms)


  19 passing (43s)
```

## Aptos

```angular2html
(.venv) ➜  latent git:(master) ✗ aptos move test               
INCLUDING DEPENDENCY AptosFramework
INCLUDING DEPENDENCY AptosStdlib
INCLUDING DEPENDENCY MoveStdlib
BUILDING latent
Running Move unit tests
[debug] true
[debug] 1
[debug] 1
[ PASS    ] 0x1fd2ada641c9711e2bd7a9fb0ddd5ea2f535d8331eff349ad788af51488c31bc::talent_show_tests::test_complete_flow
[ PASS    ] 0x1fd2ada641c9711e2bd7a9fb0ddd5ea2f535d8331eff349ad788af51488c31bc::talent_show_tests::test_double_voting_fails
[ PASS    ] 0x1fd2ada641c9711e2bd7a9fb0ddd5ea2f535d8331eff349ad788af51488c31bc::talent_show_tests::test_initialize
[ PASS    ] 0x1fd2ada641c9711e2bd7a9fb0ddd5ea2f535d8331eff349ad788af51488c31bc::talent_show_tests::test_insufficient_stake_fails
[ PASS    ] 0x1fd2ada641c9711e2bd7a9fb0ddd5ea2f535d8331eff349ad788af51488c31bc::talent_show_tests::test_submit_audience_score
[ PASS    ] 0x1fd2ada641c9711e2bd7a9fb0ddd5ea2f535d8331eff349ad788af51488c31bc::talent_show_tests::test_submit_performance
Test result: OK. Total tests: 6; passed: 6; failed: 0
{
  "Result": "Success"
}

```