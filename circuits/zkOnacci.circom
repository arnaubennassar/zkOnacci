include "../node_modules/circomlib/circuits/smt/smtverifier.circom";
include "../node_modules/circomlib/circuits/smt/smtprocessor.circom";

/**
 * Process the next number of the fibonacci sequence
 * @param nLevels - merkle tree depth
 * @input senderInput - {Field} - Ethereum address of the sender, used to prevent front running attacks
 * @input stateRoot - {Field} - root of the Merkle tree
 * @input n - {Uint32} - the Nth element of the sequence that is being added
 * @input Fn - {Uint32} - the value of the Nth element of the Fibonacci sequence
 * @input siblingsFn[nLevels+1] - {Array(Field)} - Siblings Merkle proof to process (add) the new number of the sequence
 * @input FnMinOne - {Uint32} - the value of the N-1th element of the Fibonacci sequence
 * @input siblingsFnMinOne[nLevels+1] - {Array(Field)} - Siblings Merkle proof to demonstrate that the N-1th element of the Fibonacci sequence is already on the tree
 * @input FnMinTwo - {Uint32} - the value of the N-2th element of the Fibonacci sequence
 * @input siblingsFnMinTwo[nLevels+1] - {Array(Field)} - Siblings Merkle proof to demonstrate that the N-2th element of the Fibonacci sequence is already on the tree
 * @output senderOutput - {Field} - address of the sender to avoid front running attacks
 * @output currentRoot - {Field} - root of the Merkle Tree BEFORE adding the next fibonacci element into the tree
 * @output newRoot - {Field} - root of the Merkle Tree After adding the next fibonacci element into the tree
 */
template zkOnacci(nLevels) {
    signal private input senderInput;
    signal private input stateRoot;
    signal private input n;
    signal private input Fn;
    signal private input siblingsFn[nLevels+1];
    signal private input oldKeyFn;
    signal private input oldValueFn;
    signal private input isOld0Fn;
    signal private input FnMinOne;
    signal private input siblingsFnMinOne[nLevels+1];
    signal private input FnMinTwo;
    signal private input siblingsFnMinTwo[nLevels+1];

    signal output senderOutput;
    signal output currentRoot;
    signal output newRoot;

    var i;

    // Proof that Fn-1 is already on the tree
    component smtFnMinOneExists = SMTVerifier(nLevels+1);
	smtFnMinOneExists.enabled <== 1;
	smtFnMinOneExists.fnc <== 0;
	smtFnMinOneExists.root <== stateRoot;
	for (i=0; i<nLevels+1; i++) {
		smtFnMinOneExists.siblings[i] <== siblingsFnMinOne[i];
	}
	smtFnMinOneExists.oldKey <== 0;
	smtFnMinOneExists.oldValue <== 0;
	smtFnMinOneExists.isOld0 <== 0;
	smtFnMinOneExists.key <== n-1;
	smtFnMinOneExists.value <== FnMinOne;
    
    // Proof that Fn-2 is already on the tree
    component smtFnMinTwoExists = SMTVerifier(nLevels+1);
	smtFnMinTwoExists.enabled <== 1;
	smtFnMinTwoExists.fnc <== 0;
	smtFnMinTwoExists.root <== stateRoot;
	for (i=0; i<nLevels+1; i++) {
		smtFnMinTwoExists.siblings[i] <== siblingsFnMinTwo[i];
	}
	smtFnMinTwoExists.oldKey <== 0;
	smtFnMinTwoExists.oldValue <== 0;
	smtFnMinTwoExists.isOld0 <== 0;
	smtFnMinTwoExists.key <== n-2;
	smtFnMinTwoExists.value <== FnMinTwo;
    
    // Assert that Fn-2 + Fn-1 = Fn
    Fn === FnMinOne + FnMinTwo
    
    // Process Fn: add it to the tree to get new root
    // TODO: Test if this also proofs the non existence of Fn before processing,
    // if not check that new root is different from old root in the SC
    component processor = SMTProcessor(nLevels+1);
    processor.oldRoot <== stateRoot;
    for (i = 0; i < nLevels+1; i++) {
        processor.siblings[i] <== siblingsFn[i];
    }
    processor.oldKey <== oldKeyFn;
    processor.oldValue <== oldValueFn;
    processor.isOld0 <== 0;
    processor.newKey <== n;
    processor.newValue <== Fn;
    // Table processor functions:
    // | func[0] | func[1] | Function |
    // |:-------:|:-------:|:--------:|
    // |    0    |    0    |   NOP    |
    // |    0    |    1    |  UPDATE  |
    // |    1    |    0    |  INSERT  |
    // |    1    |    1    |  DELETE  |
    processor.fnc[0] <== 1
    processor.fnc[1] <== 0

    // Output
    senderOutput <== senderInput;
    currentRoot <== stateRoot;
    newRoot <== processor.newRoot;
}

component main = zkOnacci(6);