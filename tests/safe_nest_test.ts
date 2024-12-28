import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Ensure that deposit works correctly",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('safe-nest', 'deposit', [
                types.uint(1000)
            ], wallet1.address)
        ]);
        
        block.receipts[0].result.expectOk().expectBool(true);
        
        // Check balance
        let balanceBlock = chain.mineBlock([
            Tx.contractCall('safe-nest', 'get-balance', [
                types.principal(wallet1.address)
            ], deployer.address)
        ]);
        
        assertEquals(balanceBlock.receipts[0].result.expectOk(), types.uint(1000));
    }
});

Clarinet.test({
    name: "Test withdrawal with time lock",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // First set time lock
        let setupBlock = chain.mineBlock([
            Tx.contractCall('safe-nest', 'set-time-lock', [
                types.uint(10)
            ], deployer.address),
            Tx.contractCall('safe-nest', 'deposit', [
                types.uint(1000)
            ], wallet1.address)
        ]);
        
        setupBlock.receipts.map(receipt => receipt.result.expectOk());
        
        // Try withdrawal before time lock
        let withdrawBlock = chain.mineBlock([
            Tx.contractCall('safe-nest', 'withdraw', [
                types.uint(500)
            ], wallet1.address)
        ]);
        
        withdrawBlock.receipts[0].result.expectErr(types.uint(103)); // err-time-locked
    }
});

Clarinet.test({
    name: "Test emergency withdrawal",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // Setup wallet1 as emergency address and signer
        let setupBlock = chain.mineBlock([
            Tx.contractCall('safe-nest', 'add-signer', [
                types.principal(wallet1.address)
            ], deployer.address)
        ]);
        
        setupBlock.receipts[0].result.expectOk();
        
        // Test emergency withdrawal
        let emergencyBlock = chain.mineBlock([
            Tx.contractCall('safe-nest', 'emergency-withdraw', [
                types.uint(100)
            ], wallet1.address)
        ]);
        
        // Should fail as wallet1 is not emergency address
        emergencyBlock.receipts[0].result.expectErr(types.uint(101)); // err-not-authorized
    }
});