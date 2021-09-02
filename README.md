# zkOnacci

CTF game where players will need to create a zkProof that demonstrates the knowledge of the next number of the [Fibonacci sequence](https://en.wikipedia.org/wiki/Fibonacci_number).

Flags will be deployed on Ethereum in a form of NFTs (note that in the current spec this is represented just as a list of addresses who captured the flag because this is a WIP), and will be captured every time a player submits a valid proof.

Keep in mind that the goal is not to preserve privacy in terms of who knows which number of the series, but to obfuscate the problem in a way that is hard for the CTF players to know what they have to input. It would be very obvious what to do if the SC calculated the next value of the sequence and pass it as output of the circuit.

The SC is currently deployed on Rinkeby at `0x09aC8A7DD8D00C049af7C6117ECa9E3aeD8a43Ac`

## Requirements

- [Node](https://nodejs.org/en/), it's recommende to use [nvm](https://github.com/nvm-sh/nvm) to easily choose the right version (14.17.5)
- Circom: `npm install -g circom`
- snarkJS: `npm install -g snarkjs`
- [Geth tooling](https://github.com/ethereum/go-ethereum#executables): abigen
- [Solidity compiler (solc)](https://docs.soliditylang.org/en/v0.8.6/installing-solidity.html), it's recommended to use [solc-select](https://github.com/crytic/solc-select) to easily choose the right version (0.8.6)
- [Go 1.16](https://golang.org/doc/install)

## Setup

Install dependencies: `npm i`. Note that this will run the common phase of the trusted setup, for testing purposes.

## Build

- Compile everything: `npm build`
- Compile circuits only: `npm build-circuits`
- Compile contracts only: `npm build-contracts`

Note that it's required to rebuild the contracts if the circuits are changed in order to be able to run tests. Therefore it's recommended to use always `npn run build` unless changes only affect contracts, in this case it's safe and faster to use `npm run build-contracts`

## Architecture

In order to obfuscate the solution (a valid proof that demonstrates the knowledge of the next number of the fibonacci sequence), the state (already submitted numbers) will be represented as a Merkle tree as follows:

| Leaf index | Value                 |
| ---------- | --------------------- |
| 0          | 0                     |
| 1          | 1                     |
| 2          | 1                     |
| 3          | 2                     |
| 4          | 3                     |
| ...        | ...                   |
| N          | Leaf[N-1] + Leaf[N-2] |

### Circuit

#### Private inputs

- senderInput: Ethereum address of the sender, used to prevent front running attacks
- stateRoot: root of the Merkle tree
- n: the Nth element of the sequence that is being added
- Fn: the value of the Nth element of the Fibonacci sequence
- siblingsFn: siblings Merkle proof to process (add) the new number of the sequence
- FnMinOne: the value of the N-1th element of the Fibonacci sequence
- siblingsFnMinOne: siblings Merkle proof to demonstrate that the N-1th element of the Fibonacci sequence is already on the tree
- FnMinTwo: the value of the N-2th element of the Fibonacci sequence
- siblingsFnMinTwo: siblings Merkle proof to demonstrate that the N-2th element of the Fibonacci sequence is already on the tree

#### Output

- senderOutput: address of the sender to avoid front running attacks
- currentRoot: root of the Merkle Tree BEFORE adding the next fibonacci element into the tree
- newRoot: root of the Merkle Tree AFTER adding the next fibonacci element into the tree

#### Constrains

- Fn = FnMinOne + FnMinTwo
- The two previous numbers existed in the tree before the call (epMinOne, epMinTwo are valid against currentRoot)
- The new number exists in the tree after the call (epN is valid against nextRoot)

### Smart contract

The SC will be deployed with an initial value of the `currentRoot` that represent the tree when it has the two first numbers (otherwise some constrains would always fail in the first iteration)

Main interface will be `captureTheFlag`. This function will:

- Verify the zkProof
- If proof succeeds:
  - Update the root stored in the SC
  - Mint an NFT to the sender
