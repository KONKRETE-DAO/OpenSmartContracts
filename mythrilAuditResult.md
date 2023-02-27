==== Dependence on predictable environment variable ====
SWC ID: 116
Severity: Low
Contract: KonkreteVault
Function name: getStep()
PC address: 9255
Estimated Gas Usage: 1041 - 1136
A control flow decision is made based on The block.timestamp environment variable.
The block.timestamp environment variable is used to determine a control flow decision. Note that the values of variables like coinbase, gaslimit, block number and timestamp are predictable and can be manipulated by a malicious miner. Also keep in mind that attackers know hashes of earlier blocks. Don't use any of those environment variables as sources of randomness and be aware that use of these variables introduces a certain level of trust into miners.

---

In file: contracts/KonkreteVault.sol:536

if (block.timestamp < depositsStart) return SaleStep.PREAUCTION

---

Initial State:

Account: [CREATOR], balance: 0x0, nonce:0, storage:{}
Account: [ATTACKER], balance: 0x0, nonce:0, storage:{}

Transaction Sequence:

Caller: [CREATOR], calldata: , decoded_data: , value: 0x0
Caller: [SOMEGUY], function: getStep(), txdata: 0x9e5288a0, value: 0x0

==== Dependence on predictable environment variable ====
SWC ID: 116
Severity: Low
Contract: KonkreteVault
Function name: getStep()
PC address: 9275
Estimated Gas Usage: 1866 - 1961
A control flow decision is made based on The block.timestamp environment variable.
The block.timestamp environment variable is used to determine a control flow decision. Note that the values of variables like coinbase, gaslimit, block number and timestamp are predictable and can be manipulated by a malicious miner. Also keep in mind that attackers know hashes of earlier blocks. Don't use any of those environment variables as sources of randomness and be aware that use of these variables introduces a certain level of trust into miners.

---

In file: contracts/KonkreteVault.sol:537

if (block.timestamp < depositsStop) return SaleStep.SALE

---

Initial State:

Account: [CREATOR], balance: 0x0, nonce:0, storage:{}
Account: [ATTACKER], balance: 0x0, nonce:0, storage:{}

Transaction Sequence:

Caller: [CREATOR], calldata: , decoded_data: , value: 0x0
Caller: [SOMEGUY], function: getStep(), txdata: 0x9e5288a0, value: 0x0
