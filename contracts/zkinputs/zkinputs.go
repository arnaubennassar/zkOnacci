package zkinputs

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"math/big"
	"os/exec"

	"github.com/ethereum/go-ethereum/common"
	"github.com/iden3/go-circom-prover-verifier/parsers"
	"github.com/iden3/go-merkletree"
)

type ZKInput struct {
	Sender           common.Address     `json:"senderInput"`
	Root             *merkletree.Hash   `json:"stateRoot"`
	N                int                `json:"n"`
	Fn               int                `json:"Fn"`
	SiblingsFn       []*merkletree.Hash `json:"siblingsFn"`
	OldKeyFn         *merkletree.Hash   `json:"oldKeyFn"`
	OldValueFn       *merkletree.Hash   `json:"oldValueFn"`
	IsOld0Fn         bool               `json:"isOld0Fn"`
	FnMinOne         int                `json:"FnMinOne"`
	SiblingsFnMinOne []*merkletree.Hash `json:"siblingsFnMinOne"`
	FnMinTwo         int                `json:"FnMinTwo"`
	SiblingsFnMinTwo []*merkletree.Hash `json:"siblingsFnMinTwo"`
}

func GenerateProof(input ZKInput, circomArtifactsPath string) (
	proofA [2]*big.Int,
	proofB [2][2]*big.Int,
	proofC [2]*big.Int,
	err error,
) {
	inputJson, err := json.Marshal(input)
	if err != nil {
		return
	}
	if err = ioutil.WriteFile(circomArtifactsPath+`/input.json`, inputJson, 0777); err != nil {
		return
	}
	// Calculate witness
	var cmdOut []byte
	if cmdOut, err = exec.Command(
		`snarkjs`, `wtns`, `calculate`,
		circomArtifactsPath+`/zkOnacci.wasm`, circomArtifactsPath+`/input.json`, circomArtifactsPath+`/witness.wtns`,
	).Output(); err != nil {
		fmt.Println(string(cmdOut))
		return
	}
	// Generate proof
	if cmdOut, err = exec.Command(`snarkjs`, `groth16`, `prove`,
		circomArtifactsPath+`/zkOnacci_final.zkey`, circomArtifactsPath+`/witness.wtns`,
		circomArtifactsPath+`/proof.json`, circomArtifactsPath+`/public.json`,
	).Output(); err != nil {
		fmt.Println(string(cmdOut))
		return
	}
	proofJSON, err := ioutil.ReadFile(circomArtifactsPath + "/proof.json")
	if err != nil {
		return
	}
	proof, err := parsers.ParseProof(proofJSON)
	proofSC := parsers.ProofToSmartContractFormat(proof)
	a0, _ := big.NewInt(0).SetString(proofSC.A[0], 10)
	a1, _ := big.NewInt(0).SetString(proofSC.A[1], 10)
	b00, _ := big.NewInt(0).SetString(proofSC.B[0][0], 10)
	b01, _ := big.NewInt(0).SetString(proofSC.B[0][1], 10)
	b10, _ := big.NewInt(0).SetString(proofSC.B[1][0], 10)
	b11, _ := big.NewInt(0).SetString(proofSC.B[1][1], 10)
	c0, _ := big.NewInt(0).SetString(proofSC.C[0], 10)
	c1, _ := big.NewInt(0).SetString(proofSC.C[1], 10)
	return [2]*big.Int{a0, a1},
		[2][2]*big.Int{{b00, b01}, {b10, b11}},
		[2]*big.Int{c0, c1},
		nil
}
