// // use cardano/assets.{PolicyId}
// use aiken/collection/list.{at, filter, has, foldl}
// use cardano/address.{Credential, VerificationKey, Script}
// use cardano/assets.{lovelace_of}
// use cardano/certificate.{Certificate}
// use cardano/transaction.{OutputReference, Transaction, find_input}
// use cocktail/vodka_value.{get_all_value_to}
// use stake_validator.{spend}
// // use types.{Percent}
// use aiken/math/rational.{mul, sub, from_int, new, floor}
// use aiken/math.{abs}


// // The validator is parameterized with PubKetHashes and a percent
// // NOTE:'percent' is the prcentage you have in mind for the owner_one multiplied by 100. 
// // The multiplication w/ 100 is for two decimal precision

// validator revenue_share(owner_one: ByteArray, owner_two: ByteArray, percent: Int) {
//   spend(
//     _datum: Option<Data>,
//     _redeemer: Data,
//     utxo: OutputReference,
//     self: Transaction,
//   ) {
//     let Transaction{inputs, ..} = self
//     expect Some(own_input) = find_input(inputs, utxo)
//     let own_address = own_input.output.address
//     expect Script(withdraw_script_hash) = own_address.payment_credential
//     spend(withdraw_script_hash, fn(_redeemer, _amount) { True }, self)
//   }


//   withdraw(_redeemer: Data, _account: Credential, self: Transaction) {
//       let Transaction { inputs,outputs, extra_signatories, .. } = self
//       // Get lovelace from all other sources other than owners
//       // The user is expected to only interact with this contact and not mix actions
//       let input_list_not_owners = filter(inputs, fn(input) { input.output.address.payment_credential != VerificationKey(owner_one) || input.output.address.payment_credential != VerificationKey(owner_two) })
//       let total_input_ada_not_owners = foldl(input_list_not_owners, 0, fn(acc, input) { acc + lovelace_of(input.output.value) })
//       // List of outputs to each owner
//       let output_list_owner_one = filter(outputs, fn(output) { output.address.payment_credential == VerificationKey(owner_one) })
//       let output_list_owner_two = filter(outputs, fn(output) { output.address.payment_credential == VerificationKey(owner_two) })
//       // Get the address of each owner
//       expect Some(some_owner_one_output) = at(output_list_owner_one, 0)
//       expect Some(some_owner_two_output) = at(output_list_owner_two, 0)
//       let owner_one_address = some_owner_one_output.address
//       let owner_two_address = some_owner_two_output.address
//       // Get the total amount of ADA withdrawn to each owner
//       let total_ada_to_owner_one = lovelace_of(get_all_value_to(output_list_owner_one, owner_one_address))
//       let total_ada_to_owner_two = lovelace_of(get_all_value_to(output_list_owner_two, owner_two_address))
//       // Get the total ADA inputted by each owner (only one owner is withdrawing so in almost all cases the input from the other owner is 0)
//       let input_list_owner_one = filter(inputs, fn(input) { input.output.address.payment_credential == VerificationKey(owner_one) })
//       let input_list_owner_two = filter(inputs, fn(input) { input.output.address.payment_credential == VerificationKey(owner_two) })
//       let total_ada_inputted_owner_one = foldl(input_list_owner_one, 0, fn(acc, input) { acc + lovelace_of(input.output.value) })
//       let total_ada_inputted_owner_two = foldl(input_list_owner_two, 0, fn(acc, input) { acc + lovelace_of(input.output.value) })
//       // Get the total ADA withdrawn by each owner
//       let total_ada_withdrawn_owner_one = abs(total_ada_to_owner_one - total_ada_inputted_owner_one)
//       let total_ada_withdrawn_owner_two = abs(total_ada_to_owner_two - total_ada_inputted_owner_two)
//       // Check that the outputs are only to the owners
//       let outputs_only_to_owners = (filter(outputs, fn(output) {output.address.payment_credential != VerificationKey(owner_one) || output.address.payment_credential != VerificationKey(owner_two)})) == []

//       // Final checks
//       expect Some(percent_rational) = new(percent, 10000)
//       when
//         (has(extra_signatories, owner_one), has(extra_signatories, owner_two))
//       is {
//         (True, False) -> {
//           trace@"Owner_one is withdrawing"
//           and{
//             (total_ada_withdrawn_owner_one <= floor(mul(from_int(total_input_ada_not_owners), percent_rational)))?,
//             (total_ada_withdrawn_owner_two >= floor(mul(from_int(total_input_ada_not_owners), sub(from_int(1), percent_rational))))?,
//             outputs_only_to_owners?,
//           }
//         }

//         (False, True) -> {
//           trace@"Owner_two is withdrawing"
//           and{
//             (total_ada_withdrawn_owner_two <= floor(mul(from_int(total_input_ada_not_owners), sub(from_int(1), percent_rational))))?,
//             (total_ada_withdrawn_owner_one >= floor(mul(from_int(total_input_ada_not_owners), percent_rational)))?,
//             outputs_only_to_owners?,
//           }
//         }

//         _ -> {
//           trace@"Wrong signatories or two signatories"
//           False
//           }
//       }
//     }

//   publish(_redeemer: Data, _certificate: Certificate, self: Transaction) {
//     let Transaction { extra_signatories, .. } = self
//     has(extra_signatories, owner_one) || has(extra_signatories, owner_two) == True?
//   }

//   else(_) {
//     fail
//   }
// }
