use revenue_share_1
use mocktail.{mocktail_tx, mock_pub_key_hash, mock_tx_hash, mock_pub_key_address,mock_script_stake_key_hash, 
mock_script_address, tx_out, tx_in, add_extra_signatory, add_certificate,
mock_utxo_ref, complete, script_withdrawal, add_redeemer, mock_script_hash}
use cardano/address.{VerificationKey, Address, Script, Inline}
use cardano/certificate.{RegisterAndDelegateCredential, DelegateBlockProduction,}
use cardano/transaction.{Transaction, Withdraw}
use cardano/assets.{from_lovelace}
use aiken/builtin.{i_data}
// use cardano/certificate.{Never}


// Create test cases
type TestCase {
    // correct_output: Bool,
    lovelace_withdraw: Bool,
    // lovelace_spend: Bool,
    // correct_signatories: Bool,
    owner_one: Bool,
    owner_two: Bool,
    more_than_two_owners: Bool,
    certificate: Bool,
    owner_one_lovelace: Int,
    owner_two_lovelace: Int,
    withdraw_lovelace: Int,
}

// Create correct and wrong owners
const owner_one_hash = mock_pub_key_hash(0)
const owner_two_hash = mock_pub_key_hash(1)
const owner_one_address = Address{payment_credential: VerificationKey(owner_one_hash), stake_credential: None}
const owner_two_address = Address{payment_credential: VerificationKey(owner_two_hash), stake_credential: None}
const wrong_owner_address = mock_pub_key_address(2, None)

// Build Base Transaction
fn mock_tx(test_case: TestCase) -> Transaction {
    let TestCase {lovelace_withdraw, 
    owner_one, owner_two, more_than_two_owners, 
    owner_one_lovelace, owner_two_lovelace,
    withdraw_lovelace, certificate } = test_case
    mocktail_tx()
        |> tx_out(owner_one || owner_two, owner_one_address, from_lovelace(owner_one_lovelace)) // owner one gets the lovelace
        |> tx_out(owner_one || owner_two, owner_two_address, from_lovelace(owner_two_lovelace)) // owner two gets the lovelace
        |> tx_out(more_than_two_owners, wrong_owner_address, from_lovelace(10_000_000)) // Some third person gets lovelace
        |> tx_in(owner_one, mock_tx_hash(0), 1, from_lovelace(10_000_000), owner_one_address) // owner one inputs the lovelace
        |> tx_in(!owner_one, mock_tx_hash(1), 1, from_lovelace(10_000_000), owner_two_address) // owner two inputs the lovelace
        |> tx_in(True, mock_tx_hash(0), 0, from_lovelace(100_000_000), mock_script_address(0, Some(Inline(Script(mock_script_stake_key_hash(0)))))) // add withdrawal script input
        |> script_withdrawal(lovelace_withdraw, mock_script_hash(0), withdraw_lovelace) // add withdrawal script
        |> complete() 
        |> add_extra_signatory(owner_one, owner_one_hash) // add owner one as an extra signatory
        |> add_extra_signatory(!owner_one && owner_two, owner_two_hash) // add owner two as an extra signatory
        |> add_certificate(certificate, 
            RegisterAndDelegateCredential{
                credential: Script(mock_script_stake_key_hash(0)), 
                delegate: DelegateBlockProduction{stake_pool: "pool1vx9tzlkgafernd9vpjpxkenutx2gncj4yn88fpq69823qlwcqrt"},
                deposit: 2_000_000,
            }) // add certificate for credential registration + delegation to a pool
        |> add_redeemer(True, Pair(Withdraw(Script(mock_script_hash(0))), i_data(0))) // add purpose and empty redeemer
}


// Passing Test: No lovelace withdrawal, only spend
test pass_spend_zero_lovelace_withdrawal() {
    let test_case = TestCase{
        lovelace_withdraw: True,
        owner_one: True,
        owner_two: True,
        more_than_two_owners: False,
        certificate: False,
        owner_one_lovelace: 50_000_000,
        owner_two_lovelace: 50_000_000,
        withdraw_lovelace: 0,
    }
    let tx = mock_tx(test_case)
    revenue_share_1.revenue_share.spend(owner_one_hash, owner_two_hash, 5000, None, Void, mock_utxo_ref(0, 0), tx)
}

test pass_withdraw_zero_lovelace_withdrawal() {
    let test_case = TestCase{
        lovelace_withdraw: True,
        owner_one: True,
        owner_two: True,
        more_than_two_owners: False,
        certificate: False,
        owner_one_lovelace: 50_000_000,
        owner_two_lovelace: 50_000_000,
        withdraw_lovelace: 0,
    }
    let tx = mock_tx(test_case)
    revenue_share_1.revenue_share.withdraw(owner_one_hash, owner_two_hash, 5000, Void, Script(mock_script_stake_key_hash(0)), tx)
}

// Passing Test: Second owner withdraws
test pass_withdraw_second_owner() {
    let test_case = TestCase{
        lovelace_withdraw: True,
        owner_one: False,
        owner_two: True,
        more_than_two_owners: False,
        certificate: False,
        owner_one_lovelace: 50_000_000,
        owner_two_lovelace: 50_000_000,
        withdraw_lovelace: 10_000_000,
    }
    let tx = mock_tx(test_case)
    revenue_share_1.revenue_share.withdraw(owner_one_hash, owner_two_hash, 5000, Void, Script(mock_script_stake_key_hash(0)), tx)
}

// Passing Test: With lovelace in withdraw
test pass_spend_with_lovelace_withdrawal() {
    let test_case = TestCase{
        lovelace_withdraw: True,
        owner_one: True,
        owner_two: True,
        more_than_two_owners: False,
        certificate: False,
        owner_one_lovelace: 50_000_000,
        owner_two_lovelace: 50_000_000,
        withdraw_lovelace: 10_000_000,
    }
    let tx = mock_tx(test_case)
    revenue_share_1.revenue_share.spend(owner_one_hash, owner_two_hash, 5000, None, Void, mock_utxo_ref(0, 0), tx)
}

test pass_withdraw_with_lovelace_withdrawal() {
    let test_case = TestCase{
        lovelace_withdraw: True,
        owner_one: True,
        owner_two: True,
        more_than_two_owners: False,
        certificate: False,
        owner_one_lovelace: 50_000_000,
        owner_two_lovelace: 50_000_000,
        withdraw_lovelace: 10_000_000,
    }
    let tx = mock_tx(test_case)
    revenue_share_1.revenue_share.withdraw(owner_one_hash, owner_two_hash, 5000, Void, Script(mock_script_stake_key_hash(0)), tx)
}

// Failing Test: The percentage lovelace does not match
test fail_withdraw_wrong_percent_split() fail{
    let test_case = TestCase{
        lovelace_withdraw: True,
        owner_one: True,
        owner_two: True,
        more_than_two_owners: False,
        certificate: False,
        owner_one_lovelace: 50_000_000,
        owner_two_lovelace: 39_000_000,
        withdraw_lovelace: 10_000_000,
    }
    let tx = mock_tx(test_case)
    revenue_share_1.revenue_share.withdraw(owner_one_hash, owner_two_hash, 5000, Void, Script(mock_script_stake_key_hash(0)), tx)
}

// Failing Test: Outputs to more than two owners
test fail_withdraw_outputs_to_more_than_two_owners() fail{
    let test_case = TestCase{
        lovelace_withdraw: True,
        owner_one: True,
        owner_two: True,
        more_than_two_owners: True,
        certificate: False,
        owner_one_lovelace: 50_000_000,
        owner_two_lovelace: 50_000_000,
        withdraw_lovelace: 10_000_000,
    }
    let tx = mock_tx(test_case)
    revenue_share_1.revenue_share.withdraw(owner_one_hash, owner_two_hash, 5000, Void, Script(mock_script_stake_key_hash(0)), tx)
}

// Passing Test: Certificate w/ registration and pool delegation
test pass_certificate_publish(){
    let test_case = TestCase{
        lovelace_withdraw: False,
        owner_one: True,
        owner_two: True,
        more_than_two_owners: False,
        certificate: True,
        owner_one_lovelace: 50_000_000,
        owner_two_lovelace: 50_000_000,
        withdraw_lovelace: 10_000_000,
    }
    let tx = mock_tx(test_case)
    revenue_share_1.revenue_share.publish(owner_one_hash, owner_two_hash, 5000, Void, RegisterAndDelegateCredential{
                credential: Script(mock_script_stake_key_hash(0)), 
                delegate: DelegateBlockProduction{stake_pool: "pool1vx9tzlkgafernd9vpjpxkenutx2gncj4yn88fpq69823qlwcqrt"},
                deposit: 2_000_000,
            }, tx)
}

// Failing Test: Certificate w/ registration and pool delegation no owner signatures
test fail_certificate_publish_no_owner_signatures() fail{
    let test_case = TestCase{
        lovelace_withdraw: False,
        owner_one: False,
        owner_two: False,
        more_than_two_owners: False,
        certificate: True,
        owner_one_lovelace: 50_000_000,
        owner_two_lovelace: 50_000_000,
        withdraw_lovelace: 10_000_000,
    }
    let tx = mock_tx(test_case)
    revenue_share_1.revenue_share.publish(owner_one_hash, owner_two_hash, 5000, Void, RegisterAndDelegateCredential{
                credential: Script(mock_script_stake_key_hash(0)), 
                delegate: DelegateBlockProduction{stake_pool: "pool1vx9tzlkgafernd9vpjpxkenutx2gncj4yn88fpq69823qlwcqrt"},
                deposit: 2_000_000,
            }, tx)
}