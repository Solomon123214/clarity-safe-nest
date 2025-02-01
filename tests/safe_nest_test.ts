import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

// [Previous tests remain unchanged...]

Clarinet.test({
    name: "Test multi-signature withdrawal process",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        
        // Setup signers and deposit
        let setupBlock = chain.mineBlock([
            Tx.contractCall('safe-nest', 'add-signer', [
                types.principal(wallet1.address)
            ], deployer.address),
            Tx.contractCall('safe-nest', 'add-signer', [
                types.principal(wallet2.address)
            ], deployer.address),
            Tx.contractCall('safe-nest', 'deposit', [
                types.uint(1000)
            ], wallet1.address)
        ]);
        
        setupBlock.receipts.map(receipt => receipt.result.expectOk());
        
        // Initiate withdrawal
        let initiateBlock = chain.mineBlock([
            Tx.contractCall('safe-nest', 'initiate-withdrawal', [
                types.uint(500)
            ], wallet1.address)
        ]);
        
        const withdrawalId = initiateBlock.receipts[0].result.expectOk();
        
        // Sign withdrawal
        let signBlock = chain.mineBlock([
            Tx.contractCall('safe-nest', 'sign-withdrawal', [
                withdrawalId
            ], wallet1.address),
            Tx.contractCall('safe-nest', 'sign-withdrawal', [
                withdrawalId
            ], wallet2.address)
        ]);
        
        signBlock.receipts[1].result.expectOk().expectBool(true);
        
        // Verify withdrawal completed
        let balanceBlock = chain.mineBlock([
            Tx.contractCall('safe-nest', 'get-balance', [
                types.principal(wallet1.address)
            ], deployer.address)
        ]);
        
        assertEquals(balanceBlock.receipts[0].result.expectOk(), types.uint(500));
    }
});
