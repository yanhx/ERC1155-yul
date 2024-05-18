/// @title ERC-1155 Token Contract in YUL (Assembly)
/// @notice the Spec is here: https://eips.ethereum.org/EIPS/eip-1155
///  An ERC-1155 token contract implemented in YUL (Assembly) language

// ╔══════════════════════════════════════════╗
// ║                 ERC1155                  ║
// ╚══════════════════════════════════════════╝

object "ERC1155" {
  code {
    // Store the initial URI
    sstore(0, "https://ryan.com/")
    
    // Copy the runtime code to memory and return it
    datacopy(0, dataoffset("Runtime"), datasize("Runtime"))
    return(0, datasize("Runtime"))
  }
  
  // ╔══════════════════════════════════════════╗
  // ║                Runtime                   ║
  // ╚══════════════════════════════════════════╝

  object "Runtime" {
    // Return the calldata
    code {
      // Ensure no Ether was sent with the call
      require(iszero(callvalue()))

      // Load the function selector from calldata
      //let s := div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)
      let s:= shr(0xe0, calldataload(0))

      // Switch statement to handle different function calls
      switch s
        // Query the URI of a token
        case 0x0e89341c { // uri(uint256)
          uri(decodeAsUint(0))
        } 
        
        // balanceOf(address,uint256)
        case 0x00fdd58e {
          returnUint(balanceOf(decodeAsAddress(0), decodeAsUint(1)))
        }
        
        // mint(address,uint256,uint256)
        case 0x156e29f6 {
          mint(decodeAsAddress(0), decodeAsUint(1), decodeAsUint(2), 0)
        }

        // mint(address,uint256,uint256,bytes)
        // TODO: add callback - DONE
        case 0x731133e9 {
          mint(decodeAsAddress(0), decodeAsUint(1), decodeAsUint(2), decodeAsUint(3))
        }

        // batchMint(address,uint256[],uint256[],bytes)
        // TODO:   - DONE
        case 0xb48ab8b6 {
          batchMint(decodeAsAddress(0))
        }
        
        // balanceOfBatch(address[],uint256[])
        case 0x4e1273f4 { 
          balanceOfBatch()
        }
        
        // setApprovalForAll(address,bool)
        case 0xa22cb465 { 
          setApprovalForAll(decodeAsAddress(0), decodeAsUint(1))
        }
        
        // isApprovedForAll(address,address)
        case 0xe985e9c5 { 
          returnUint(isApprovedForAll(decodeAsAddress(0), decodeAsAddress(1)))
        }

        // safeTransferFrom(address,address,uint256,uint256,bytes)
        case 0xf242432a { 
          safeTransferFrom(decodeAsAddress(0), decodeAsAddress(1), decodeAsUint(2), decodeAsUint(3), decodeAsUint(4))
        }
        
        // safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)
        // TODO : add callback  -DONE
        case 0x2eb2c2d6 { 
          safeBatchTransferFrom(decodeAsAddress(0), decodeAsAddress(1))
        }

        // burn(uint256,uint256)
        case 0xb390c0ab {
          burn(caller(), decodeAsUint(0), decodeAsUint(1))
        }

        // burn(address from, uint256 id, uint256 amount)
        // TODO - DONE
        case 0xf5298aca {
          burn(decodeAsAddress(0), decodeAsUint(1), decodeAsUint(2))
        }

        // batchBurn(address from, uint256[] calldata ids, uint256[] calldata amounts)
        // TODO
        case 0xf6eb127a {
          batchBurn(decodeAsAddress(0))
        }
        
        // Revert for unknown function calls
        default {
          revert(0,0)
        }

      // ╔══════════════════════════════════════════╗
      // ║         Decoding Helper Functions        ║
      // ╚══════════════════════════════════════════╝

      /// @dev Function to decode calldata values as an address
      /// @param offset The position of the address in the calldata
      /// @return v The decoded address from the calldata
      function decodeAsAddress(offset) -> v {
        /// Ensure the decoded value is a valid address
        v := decodeAsUint(offset)

        /// If the decoded value is not a valid address, revert the transaction
        if iszero(iszero(and(v, not(0xffffffffffffffffffffffffffffffffffffffff)))) {
          revert(0, 0)
        }
      }

      /// @dev Function to decode calldata values as a uint
      /// @param offset The position of the uint in the calldata
      /// @return v The decoded uint from the calldata
      function decodeAsUint(offset) -> v {
        /// Calculate the position of the uint in calldata
        let pos := add(4, mul(offset, 0x20))

        /// If the calldatasize is less than the position of the uint plus 0x20, revert the transaction
        if lt(calldatasize(), add(pos, 0x20)) {
            revert(0, 0)
        }

        /// Load the uint value from calldata at the calculated position
        v := calldataload(pos)
      }

    
      // ╔══════════════════════════════════════════╗
      // ║              Storage Layout              ║
      // ╚══════════════════════════════════════════╝
      
      /// @dev Function to get the URI position
      /// @return p The URI position, which is set to 0 in this implementation
      function uriPos() -> p { p := 0 }

      /// @dev Function to calculate the storage offset for a given account's balance
      /// @param account The address of the account
      /// @return offset The storage offset for the given account's balance
      function balanceOfStorageOffset(account) -> offset {
        /// Calculate the storage offset by adding 0x1000 to the account address
        offset := add(0x1000, account)
      }

      /// @dev Function to calculate the storage offset for a given account's allowance to a spender
      /// @param account The address of the account
      /// @param spender The address of the spender
      /// @return offset The storage offset for the given account's allowance to the spender
      function allowanceStorageOffset(account, spender) -> offset {
        /// Get the storage offset for the given account's balance
        offset := balanceOfStorageOffset(account)

        /// Store the balance offset and spender address in memory
        mstore(0x00, 0x01)           //to avoid collision with balance storage
        mstore(0x20, offset)
        mstore(0x40, spender)

        /// Calculate the storage offset for the account's allowance to the spender using keccak256
        offset := keccak256(0, 0x60)
      }

      // ╔══════════════════════════════════════════╗
      // ║            Contract Functions            ║
      // ╚══════════════════════════════════════════╝

      /// @dev Function to get the balance of a token for an address
      /// @param account The address of the account
      /// @param id The token ID
      /// @return bal The balance of the token for the given account
      function balanceOf(account, id) -> bal {
        /// If the account address is the zero address, revert the transaction with an invalid owner error
        if eq(account, 0x0000000000000000000000000000000000000000) { 
          revertWithInvalidOwner()
        }

        /// Calculate the storage offset for the given account's balance and token ID
        mstore(0x00, balanceOfStorageOffset(account))
        mstore(0x20, id)

        /// Load the balance from storage
        bal := sload(keccak256(0x00, 0x40))
      }

      /// @dev Function to query the balances of multiple token IDs for multiple accounts
      function balanceOfBatch() {
        /// Decode input parameters from calldata: address offset and token ID offset
        let addressOffset := decodeAsUint(0)
        let idOffset := decodeAsUint(1)
        
        /// Load the lengths of the address and token ID arrays
        let addressArrayLength := calldataload(add(4, addressOffset))
        let idArrayLength := calldataload(add(4, idOffset))

        /// Check if the lengths of both arrays match; if not, revert the transaction with a mismatch error
        if iszero(eq(idArrayLength, addressArrayLength)) { revertWithMismatchedLengths() }

        /// Set the initial memory offset for storing the result
        let memOffset := 0x40

        /// Store the length of the output array
        mstore(memOffset, 0x20)
        memOffset := add(memOffset, 0x20)
        mstore(memOffset, addressArrayLength)
        memOffset := add(memOffset, 0x20)

        /// Iterate through each address and token ID pair
        for { let i := 0 } lt(i, idArrayLength) { i := add(i, 1) } {
          /// Load the address and token ID from the input arrays
          let account := calldataload(add(add(4, sub(memOffset, 0x60)), addressOffset))
          if eq(account, 0x0000000000000000000000000000000000000000) { 
            revertWithInvalidOwner()
          }
          let id := calldataload(add(add(4, sub(memOffset, 0x60)), idOffset))
          
          /// Retrieve the balance for the current address and token ID
          mstore(memOffset, balanceOf(account, id))
          
          /// Move the memory offset for the next balance
          memOffset := add(memOffset, 0x20)
        }
        
        /// Return the memory containing the balances array
        return (0x40, sub(memOffset, 0x40))
      }

      /// @dev Function to set or unset approval for an operator
      /// @param operator The address of the operator
      /// @param approved A boolean value representing whether the operator is approved or not
      function setApprovalForAll(operator, approved) {
        /// If the operator is the same as the caller, revert the transaction with a self-approval error
        if eq(operator, caller()) { revertWithSelfApproval() }

        /// Update the allowance storage with the approval status for the operator
        sstore(allowanceStorageOffset(caller(), operator), approved)

        /// Emit the ApprovalForAll event
        emitApprovalForAll(caller(), operator, approved)
      }

      /// @dev Function to check if an operator is approved by an account
      /// @param account The address of the account
      /// @param operator The address of the operator
      /// @return allowed A boolean value representing whether the operator is approved by the account
      function isApprovedForAll(account, operator) -> allowed {
        /// Load the approval status from the allowance storage
        allowed := sload(allowanceStorageOffset(account, operator))
      }

      /// @dev Function to safely transfer tokens between addresses
      /// @param from The address of the sender
      /// @param to The address of the recipient
      /// @param id The token ID
      /// @param amount The number of tokens to transfer
      /// @param data Additional data to pass to the recipient's onERC1155Received function (if implemented)
      function safeTransferFrom(from, to, id, amount, dataOff) {
        /// If the recipient address is the zero address, revert the transaction with a transfer to zero address error
        if iszero(to) {
            revertWithZeroAddress()
        }

        /// Check if the caller is the sender or has approval to transfer on behalf of the sender; if not, revert with a not owner or approved error
        if iszero(or(eq(caller(), from), isApprovedForAll(from, caller()))) { 
          revertWithNotOwnerOrApproved()
        }
        
        //let dataStartPos := add(4, dataOff)

        /// Calculate the storage locations for the sender's and recipient's balances
        mstore(0x00, balanceOfStorageOffset(from))
        mstore(0x20, id)
        let fromBalanceLoc := keccak256(0x00, 0x40)

        mstore(0x00, balanceOfStorageOffset(to))
        let toBalanceLoc := keccak256(0x00, 0x40)

        /// Load the sender's and recipient's balances for the specified token ID
        let fromBalance := sload(fromBalanceLoc)
        let toBalance := sload(toBalanceLoc)

        /// Check if the sender has enough tokens to transfer; if not, revert with an insufficient balance error
        if iszero(gte(fromBalance, amount)) {
          revertWithInsufficientBalance()
        }

        /// Update the sender's and recipient's balances
        sstore(fromBalanceLoc, safeSub(fromBalance, amount))
        sstore(toBalanceLoc, safeAdd(toBalance, amount))

        /// Emit the TransferSingle event
        emitTransferSingle(caller(), from, to, id, amount)

        /// Perform a safe transfer acceptance check
        doSafeTransferAcceptanceCheck(from, to, id, amount, dataOff)
      }


      /// @dev Function to safely transfer multiple tokens between addresses in a batch
      /// @param from The address of the sender
      /// @param to The address of the recipient
      function safeBatchTransferFrom(from, to) {
        /// Check if the caller is either the 'from' address or has approval for all tokens; if not, revert with a not owner or approved error
        if iszero(or(eq(caller(), from), isApprovedForAll(from, caller()))) { revertWithNotOwnerOrApproved() } 
        
        /// Check if the 'to' address is valid; if not, revert with a transfer to zero address error
        if iszero(to) { revertWithZeroAddress() }
        
        /// Decode token IDs and amounts from calldata
        let idsOffset := decodeAsUint(2)
        let amountsOffset := decodeAsUint(3)

        /// Calculate lengths of token IDs and amounts arrays
        let lenAmountsOffset := add(4, amountsOffset)
        let lenIdsOffset := add(4, idsOffset)

        let lenAmounts := calldataload(lenAmountsOffset)
        let lenIds := calldataload(lenIdsOffset)

        /// Check if the lengths of token IDs and amounts arrays are equal; if not, revert with an ids and amounts mismatch error
        if iszero(eq(lenAmounts, lenIds)) { revertWithMismatchedLengths() }

        /// Initialize the current offset
        let currentOffset := 0x20

        /// Iterate through the token IDs and amounts arrays
        for { let i := 0 } lt(i, lenIds) { i := add(i, 1) } {

            /// Load the current token ID and amount
            let id := calldataload(add(lenIdsOffset, currentOffset))
            let amount := calldataload(add(lenAmountsOffset, currentOffset))

            /// Calculate the storage locations for 'from' and 'to' balances
            mstore(0x00, balanceOfStorageOffset(from))
            mstore(0x20, id)
            let fromBalanceLoc := keccak256(0x00, 0x40)

            mstore(0x00, balanceOfStorageOffset(to))
            let toBalanceLoc := keccak256(0x00, 0x40)

            /// Load the current balances of 'from' and 'to' addresses
            let fromBalance := sload(fromBalanceLoc)
            let toBalance := sload(toBalanceLoc)

            /// Check if the 'from' address has enough balance; if not, revert with an insufficient balance error
            if iszero(gte(fromBalance, amount)) {
              log3(0x0,0x0,fromBalance,amount, id)
              revertWithInsufficientBalance()
            }

            /// Update the balances of 'from' and 'to' addresses
            sstore(fromBalanceLoc, safeSub(fromBalance, amount))
            sstore(toBalanceLoc, safeAdd(toBalance, amount))
            
            /// Update the current offset
            currentOffset := add(currentOffset, 0x20)
        }
        /// Emit the TransferBatch event
        emitTransferBatch(caller(), from, to, idsOffset, amountsOffset)

        doSafeTransferBatchAcceptanceCheck(from, to, idsOffset, amountsOffset, decodeAsUint(4))
      }

      /// @dev Function to mint tokens to an account
      /// @param account The address of the account to mint tokens to
      /// @param id The token ID
      /// @param amount The number of tokens to mint
      function mint(account, id, amount, dataOff) {
        /// If the account address is the zero address, revert the transaction with a mint to zero address error
        if iszero(account) {
            revertWithZeroAddress()
        }

        /// Calculate the storage location for the account's balance
        mstore(0x00, balanceOfStorageOffset(account))
        mstore(0x20, id)
        let loc := keccak256(0x00, 0x40)

        /// Load the account's balance, update it, and store it back
        let bal := sload(loc)
        sstore(loc, safeAdd(bal, amount))

        /// Emit the TransferSingle event
        emitTransferSingle(caller(), 0, account, id, amount)

        /// Perform a safe transfer acceptance check
        if iszero(dataOff) {
          doSafeTransferAcceptanceCheck(0, account, id, amount, "")
        }
        if iszero(iszero(dataOff)) {
          doSafeTransferAcceptanceCheck(0, account, id, amount, dataOff)
        }
      }

      function batchMint(account) {
        /// If the account address is the zero address, revert the transaction with a mint to zero address error
        if iszero(account) {
            revertWithZeroAddress()
        }

         /// Decode token IDs and amounts from calldata
         let idsOffset := decodeAsUint(1)
         let amountsOffset := decodeAsUint(2)
 
         /// Calculate lengths of token IDs and amounts arrays
         let lenAmountsOffset := add(4, amountsOffset)
         let lenIdsOffset := add(4, idsOffset)
 
         let lenAmounts := calldataload(lenAmountsOffset)
         let lenIds := calldataload(lenIdsOffset)
 
         /// Check if the lengths of token IDs and amounts arrays are equal; if not, revert with an ids and amounts mismatch error
         if iszero(eq(lenAmounts, lenIds)) { revertWithMismatchedLengths() }
        
         /// Initialize the current offset
         let currentOffset := 0x20

        /// Iterate through the token IDs and amounts arrays
        for { let i := 0 } lt(i, lenIds) { i := add(i, 1) } {

            /// Load the current token ID and amount
            let id := calldataload(add(lenIdsOffset, currentOffset))
            let amount := calldataload(add(lenAmountsOffset, currentOffset))

            /// Calculate the storage location for the account's balance
            mstore(0x00, balanceOfStorageOffset(account))
            mstore(0x20, id)
            let loc := keccak256(0x00, 0x40)

            /// Load the account's balance, update it, and store it back
            let bal := sload(loc)
            sstore(loc, safeAdd(bal, amount))

            /// Emit the TransferSingle event
            emitTransferSingle(caller(), 0, account, id, amount)

            /// Perform a safe transfer acceptance check
            // doSafeTransferAcceptanceCheck(0, account, id, amount, decodeAsUint(3))

            /// Update the current offset
            currentOffset := add(currentOffset, 0x20)
        }
        doSafeTransferBatchAcceptanceCheck(0, account, idsOffset, amountsOffset, decodeAsUint(3))

      }

      /// @dev Function to burn tokens from an account
      /// @param account The address of the account to burn tokens from
      /// @param id The token ID
      /// @param amount The number of tokens to burn
      function burn(account, id, amount) {
        /// If the account address is the zero address, revert the transaction with a burn from zero address error
        if iszero(account) {
            revertWithZeroAddress()
        }

        /// Calculate the storage location for the account's balance
        mstore(0x00, balanceOfStorageOffset(account))
        mstore(0x20, id)
        let loc := keccak256(0x00, 0x40)

        /// Load the account's balance and ensure it is greater than or equal to the burn amount; if not, revert with a burn amount exceeds balance error
        let bal := sload(loc)
        if iszero(gte(bal, amount)) {
            revertWithInsufficientBalance()
        }

        /// Update the account's balance and store it back
        sstore(loc, sub(bal, amount))

        /// Emit the TransferSingle event
        emitTransferSingle(caller(), account, 0, id, amount)
      }

      /// @dev Function to return the token URI
      /// @param index The token index
      /// @return The memory address and length containing the token URI
      function uri(index) {
        /// Store the length of the URI and the URI itself in memory
        mstore(0x00, 0x20)
        mstore(0x20, 0x12)
        mstore(0x40, sload(uriPos()))

        /// Return the memory containing the token URI
        return(0x00, 0x60)
      }

      /// @dev Function to do a safe transfer acceptance check
      /// @param from The address of the sender
      /// @param to The address of the recipient
      /// @param id The token ID
      /// @param amount The number of tokens to transfer
      /// @param data Additional data to be passed to the recipient's onERC1155Received function
      function doSafeTransferAcceptanceCheck(from, to, id, amount, dataOff) {
        /// Check the size of the recipient's code
        let size := extcodesize(to)

        /// If the recipient's code size is greater than 0, it means it's a contract
        if gt(size, 0) {
            /// Set the onERC1155Received function selector and error signature
            let selector := 0xf23a6e6100000000000000000000000000000000000000000000000000000000
            let errorSig := 0x08c379a000000000000000000000000000000000000000000000000000000000

            /// Prepare calldata for onERC1155Received(operator, from, id, amount, data)
            mstore(0x100, selector)
            mstore(0x104, caller())
            mstore(0x124, from)
            mstore(0x144, id)
            mstore(0x164, amount)
            mstore(0x184, 0xa0)

            /// Copy data to memory
            let len := copyDataToMem(0x1a4, dataOff)

            /// Clear the first 32 bytes in memory for storing the call result
            mstore(0x00, 0x00)

            /// Perform the call to the recipient's onERC1155Received function
            //log2(0x100, tmp, tmp, dataOff)
            let res := call(gas(), to, 0, 0x100, add(0xa4, len), 0x00, 0x04)

            /// If the call result matches the error signature, revert the transaction with the returned error data
            if eq(mload(0x00), errorSig) {
                returndatacopy(0x00, 0x00, returndatasize())
                revert(0x00, returndatasize())
            }

            /// If the call was unsuccessful, revert with a non-ERC1155 receiver error
            if iszero(res) {
                revertWithNonERC1155Receiver()
            }

            /// If the call result doesn't match the onERC1155Received function selector, revert with a rejected tokens error
            if iszero(eq(mload(0x00), selector)) {
                revertWithRejectedTokens()
            }
        }
      }

      function doSafeTransferBatchAcceptanceCheck(from, to, idsOffset, amountsOffset, dataOff) {
        /// Check the size of the recipient's code
        let size := extcodesize(to)

        /// If the recipient's code size is greater than 0, it means it's a contract
        if gt(size, 0) {
            /// Set the onERC1155BatchReceived function selector and error signature
            let selector := 0xbc197c8100000000000000000000000000000000000000000000000000000000
            let errorSig := 0x08c379a000000000000000000000000000000000000000000000000000000000

            /// Prepare calldata for onERC1155BatchReceived(operator, from, ids, amounts, data)
            mstore(0x100, selector)
            mstore(0x104, caller())
            mstore(0x124, from)
            mstore(0x144, add(0x20, idsOffset))
            mstore(0x164, add(0x20, amountsOffset))
            mstore(0x184, add(0x20, dataOff))

            calldatacopy(0x1a4, 0x84, sub(calldatasize(), 0x84))

            /// Clear the first 32 bytes in memory for storing the call result
            mstore(0x00, 0x00)

            /// Perform the call to the recipient's onERC1155Received function
            //log1(0x100, add(calldatasize(), 0x20), add(calldatasize(), 0x20))
            let res := call(gas(), to, 0, 0x100, add(calldatasize(), 0x24), 0x00, 0x04)

            /// If the call result matches the error signature, revert the transaction with the returned error data
            if eq(mload(0x00), errorSig) {
                returndatacopy(0x00, 0x00, returndatasize())
                revert(0x00, returndatasize())
            }

            /// If the call was unsuccessful, revert with a non-ERC1155 receiver error
            if iszero(res) {
                revertWithNonERC1155Receiver()
            }

            /// If the call result doesn't match the onERC1155Received function selector, revert with a rejected tokens error
            if iszero(eq(mload(0x00), selector)) {
                revertWithRejectedTokens()
            }
        }
      }

      // ╔══════════════════════════════════════════╗
      // ║        Calldata Encoding Functions       ║
      // ╚══════════════════════════════════════════╝

      /// @dev Function to return a uint value in memory
      /// @param v The uint value to be returned
      function returnUint(v) {
        /// Store the uint value in memory
        mstore(0, v)
        /// Return the memory location and length
        return(0, 0x20)
      }

      // ╔══════════════════════════════════════════╗
      // ║            Utility Functions             ║
      // ╚══════════════════════════════════════════╝

      /// @dev Function to check if a <= b
      /// @param a The first number to compare
      /// @param b The second number to compare
      function lte(a, b) -> r {
        /// Check if a is less than or equal to b and return the result
        r := iszero(gt(a, b))      
      }

      /// @dev Function to check if a >= b
      /// @param a The first number to compare
      /// @param b The second number to compare
      function gte(a, b) -> r {
        /// Check if a is greater than or equal to b and return the result
        r := iszero(lt(a, b))
      }

      /// @dev Function to safely add two numbers, reverting if overflow occurs
      /// @param a The first number to add
      /// @param b The second number to add
      function safeAdd(a, b) -> r {
        /// Add the two numbers
        r := add(a, b)
        /// Check if the result is less than either of the inputs and revert if it is
        if or(lt(r, a), lt(r, b)) { revert(0x00, 0x00) }
      }

      /// @dev Function to safely subtract two numbers, reverting if overflow occurs
      /// @param a The number to subtract from
      /// @param b The number to subtract
      function safeSub(a, b) -> r {
        /// Subtract b from a
        r := sub(a, b)
        /// Check if the result is greater than a and revert if it is
        if gt(r, a) { revert(0x00, 0x00) }
      }

      /// @dev Function to require a condition is true, otherwise revert
      /// @param condition The condition to check
      function require(condition) {
        /// Check if the condition is false and revert if it is
        if iszero(condition) { revert(0, 0) }
      }

      /// @dev Function to copy data from calldata to memory
      /// @param memPtr The memory pointer to start writing to
      /// @param dataOff The offset in calldata where the data starts
      function copyDataToMem(memPtr, dataOff) -> totalLength {
        /// Get the offset of the data length in calldata
        let dataLengthOff := add(dataOff, 4)
        /// Load the data length from calldata
        let dataLength := calldataload(dataLengthOff)

        /// Calculate the total length of the data to copy
        totalLength := add(0x20, dataLength) // dataLength+data
        let remainder := mod(dataLength, 0x20)
        if remainder {
            totalLength := add(totalLength, sub(0x20, remainder))
        }

        /// Copy the data from calldata to memory
        calldatacopy(memPtr, dataLengthOff, totalLength)

      }

      function copyUintToMem(memPtr, dataOff) -> totalLength {
        /// Get the offset of the data length in calldata
        let dataLengthOff := add(dataOff, 4)
        /// Load the data length from calldata
        let dataLength := calldataload(dataLengthOff)

        /// Calculate the total length of the data to copy
        totalLength := add(0x20, mul(dataLength, 0x20)) // dataLength+data


        /// Copy the data from calldata to memory
        calldatacopy(memPtr, dataLengthOff, totalLength)

      }

      // ╔══════════════════════════════════════════╗
      // ║            Events Functions              ║
      // ╚══════════════════════════════════════════╝

      /// @dev Function to emit a TransferSingle event
      /// @param operator The address of the operator performing the transfer
      /// @param from The address sending the tokens
      /// @param to The address receiving the tokens
      /// @param id The ID of the token being transferred
      /// @param amount The amount of tokens being transferred
      function emitTransferSingle(operator, from, to, id, amount) {
        /// Get the signature hash for the TransferSingle event
        let signatureHash := 0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62
        
        /// Store the token ID and amount in memory
        mstore(0x00, id)
        mstore(0x20, amount)
        
        /// Emit the TransferSingle event using log4 opcode
        log4(0x00, 0x40, signatureHash, operator, from, to)
      }


      /// @dev Emits a TransferBatch event.
      /// @param operator The address of the operator performing the transfer.
      /// @param from The address of the sender.
      /// @param to The address of the recipient.
      /// @param ids An array containing the IDs of the tokens being transferred.
      /// @param amounts An array containing the amounts of tokens being transferred.
      function emitTransferBatch(operator, from, to, ids, amounts) {
        // The hash of the TransferBatch signature for the ERC1155 standard
        let signatureHash := 0x4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb

        // Calculate lengths of token IDs and amounts arrays

        // Calculate lengths of token IDs and amounts arrays
        let lenIdsOffset := add(4, ids)

        let lenIds := calldataload(lenIdsOffset)

        let memptr := 0x00

        // Copy token IDs and amounts to memory
        mstore(memptr, 0x0000000000000000000000000000000000000000000000000000000000000040)
        memptr := add(memptr, 0x20)
        mstore(memptr, add(0x60, mul(lenIds, 0x20)))
        memptr := add(memptr, 0x20)

        let len := add(sub(calldatasize(), lenIdsOffset), 0x20)

        for { let i := 0 } lt(memptr, len) { i := add(i, 1) } {
              mstore(memptr, calldataload(add(sub(memptr, 0x40), lenIdsOffset)))
              memptr := add(memptr, 0x20)
        }
        // Emit TransferBatch event
        log4(0, memptr, signatureHash, operator, from, to)
      }

      /// @dev Emits an ApprovalForAll event.
      /// @param account The address of the account granting the approval.
      /// @param operator The address of the operator being approved.
      /// @param approved The new approval status.
      function emitApprovalForAll(account, operator, approved) {
          
        // The hash of the ApprovalForAll signature for the ERC1155 standard
        let signatureHash := 0x17307eab39ab6107e8899845ad3d59bd9653f200f220920489ca2b5937696c31
          
        // Copy the approval status to memory
        mstore(0x00, approved)

        // Emit ApprovalForAll event
        log3(0x00, 0x20, signatureHash, account, operator)
      }

      /// @dev Emits an URI event.
      /// @param value The URI value to emit.
      /// @param id The token ID associated with the URI.
      function emitURI(value, id) {
        // The hash of the URI signature for the ERC1155 standard
        let signatureHash := 0x17307eab39ab6107e8899845ad3d59bd9653f200f220920489ca2b5937696c31

        // Copy the URI value to memory
        mstore(0x00, value)

        // Emit URI event
        log2(0x00, 0x20, signatureHash, id)
      }


      // ╔══════════════════════════════════════════╗
      // ║            Reverts Functions             ║
      // ╚══════════════════════════════════════════╝

      /// Function to revert with a custom message and size
      /// Reverts with message "INVALID_OWNER"
      function revertWithInvalidOwner() {
        mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
        mstore(0x04, 0x20)
        mstore(0x24, 13)
        mstore(0x44, "INVALID_OWNER")     //0x494e56414c49445f4f574e455200000000000000000000000000000000000000
        
        revert(0x00, 0x64)
      }

      /// Function to revert with a custom message and size
      /// Reverts with message "SELF_APPROVAL"
      function revertWithSelfApproval() {
        mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
        mstore(0x04, 0x20)
        mstore(0x24, 13)
        mstore(0x44, "SELF_APPROVAL") //0x53454c465f415050524f56414c00000000000000000000000000000000000000
                      
        revert(0x00, 0x64)
      }

      /// Function to revert with a custom message and size
      /// Reverts with message "LENGTH_MISMATCH"
      function revertWithMismatchedLengths() {
        mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000) // Function selector for Error(string)
        mstore(0x04, 0x20)                                                              // Data offset
        mstore(0x24, 15)                                                               // String length
        mstore(0x44, "LENGTH_MISMATCH")                                                 // 0x4c454e4754485f4d49534d415443480000000000000000000000000000000000
                      
        revert(0x00, 0x64)
      }
        
      /// Function to revert with a custom message and size
      /// Reverts with message "UNAUTHORISED"
      function revertWithNotOwnerOrApproved() {
        mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
        mstore(0x04, 0x20)
        mstore(0x24, 12)
        mstore(0x44, "UNAUTHORISED") //0x554e415554484f52495345440000000000000000000000000000000000000000
                      
        revert(0x00, 0x64)
      }

      /// @dev Revert with a custom message and size when the balance is insufficient for transfer
      /// "INSUFFICIENT_BAL"
      function revertWithInsufficientBalance() {
        mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
        mstore(0x04, 0x20)
        mstore(0x24, 16)
        mstore(0x44, "INSUFFICIENT_BAL")  //0x494e53554646494349454e545f42414c00000000000000000000000000000000

        revert(0x00, 0x64)
      }

      
      /// Function to revert with a custom message and size
      /// @dev Reverts with message "ZERO_ADDRESS"
      function revertWithZeroAddress() {
        mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
        mstore(0x04, 0x20)
        mstore(0x24, 12)
        mstore(0x44, "ZERO_ADDRESS") //0x5a45524f5f414444524553530000000000000000000000000000000000000000
        
        revert(0x00, 0x64)
      }


      /// Function to revert with a custom message and size when ERC1155Receiver rejected tokens.
      // "REJECTED_TOKEN"
      function revertWithRejectedTokens() {
        mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
        mstore(0x04, 0x20)
        mstore(0x24, 14)
        mstore(0x44, "REJECTED_TOKEN") //0x52454a45435445445f544f4b454e000000000000000000000000000000000000

        revert(0x00, 0x64)
      }

      /// Function to revert with a custom message and size when transferring tokens to a non-ERC1155Receiver implementer.
      // "NON_RECEIVER"
      function revertWithNonERC1155Receiver() {
        mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
        mstore(0x04, 0x20)
        mstore(0x24, 12)
        mstore(0x44, "NON_RECEIVER") //0x4e4f4e5f52454345495645520000000000000000000000000000000000000000
                          
        revert(0x00, 0x64)
      }
    }
  }
}

       