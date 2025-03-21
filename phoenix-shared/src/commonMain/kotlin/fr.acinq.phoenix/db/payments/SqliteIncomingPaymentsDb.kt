/*
 * Copyright 2024 ACINQ SAS
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package fr.acinq.phoenix.db.payments

import fr.acinq.bitcoin.ByteVector32
import fr.acinq.lightning.db.AutomaticLiquidityPurchasePayment
import fr.acinq.lightning.db.Bolt11IncomingPayment
import fr.acinq.lightning.db.IncomingPayment
import fr.acinq.lightning.db.IncomingPaymentsDb
import fr.acinq.lightning.db.LightningIncomingPayment
import fr.acinq.lightning.db.OnChainIncomingPayment
import fr.acinq.lightning.wire.LiquidityAds
import fr.acinq.phoenix.data.WalletPaymentMetadata
import fr.acinq.phoenix.db.sqldelight.PaymentsDatabase
import fr.acinq.phoenix.db.didDeleteWalletPayment
import fr.acinq.phoenix.db.didSaveWalletPayment
import fr.acinq.phoenix.utils.MetadataQueue
import fr.acinq.phoenix.utils.extensions.deriveUUID
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class SqliteIncomingPaymentsDb(
    private val database: PaymentsDatabase,
    private val metadataQueue: MetadataQueue?
) : IncomingPaymentsDb {

    val metadataQueries = PaymentsMetadataQueries(database)

    override suspend fun addIncomingPayment(incomingPayment: IncomingPayment) {
        val metadata = metadataQueue?.dequeue(incomingPayment.id)
        withContext(Dispatchers.Default) {
            database.transaction {
                _addIncomingPayment(incomingPayment, metadata)
            }
        }
    }

    /**
     * This method must be called inside a transaction block.
     * Non suspending so the iOS app can call it when restoring data from the cloud.
     *
     * @param notify Set to false if `didSaveWalletPayment` should not be invoked
     *               (e.g. when downloading payments from the cloud)
     */
    fun _addIncomingPayment(incomingPayment: IncomingPayment, metadata: WalletPaymentMetadata?, notify: Boolean = true) {
        database.paymentsIncomingQueries.insert(
            id = incomingPayment.id,
            payment_hash = (incomingPayment as? LightningIncomingPayment)?.paymentHash,
            tx_id = when (incomingPayment) {
                is LightningIncomingPayment -> incomingPayment.liquidityPurchaseDetails?.txId
                is OnChainIncomingPayment -> incomingPayment.txId
                else -> null
            },
            created_at = incomingPayment.createdAt,
            received_at = incomingPayment.completedAt,
            data_ = incomingPayment
        )
        // if the payment is on-chain, save the tx id link to the db
        when (incomingPayment) {
            is OnChainIncomingPayment ->
                database.onChainTransactionsQueries.insert(
                    payment_id = incomingPayment.id,
                    tx_id = incomingPayment.txId,
                    confirmed_at = incomingPayment.confirmedAt,
                    locked_at = incomingPayment.lockedAt
                )

            else -> {}
        }
        metadata?.serialize()?.let { row ->
            metadataQueries.addMetadata(incomingPayment.id, row)
        }
        if (notify) {
            didSaveWalletPayment(incomingPayment.id, database)
        }
    }

    override suspend fun getLightningIncomingPayment(paymentHash: ByteVector32): LightningIncomingPayment? =
        withContext(Dispatchers.Default) {
            database.paymentsIncomingQueries.getByPaymentHash(paymentHash).executeAsOneOrNull() as? LightningIncomingPayment
        }

    override suspend fun receiveLightningPayment(paymentHash: ByteVector32, parts: List<LightningIncomingPayment.Part>, liquidityPurchase: LiquidityAds.LiquidityTransactionDetails?) {
        withContext(Dispatchers.Default) {
            database.transaction {
                when (val paymentInDb = database.paymentsIncomingQueries.getByPaymentHash(paymentHash).executeAsOneOrNull() as? LightningIncomingPayment) {
                    is LightningIncomingPayment -> {
                        val paymentInDb1 = paymentInDb.addReceivedParts(parts, liquidityPurchase)
                        database.paymentsIncomingQueries.update(
                            id = paymentInDb1.id,
                            data = paymentInDb1,
                            receivedAt = paymentInDb1.completedAt,
                            txId = paymentInDb1.liquidityPurchaseDetails?.txId
                        )
                        liquidityPurchase?.let {
                            when (val autoLiquidityPayment = database.paymentsOutgoingQueries.listByTxId(liquidityPurchase.txId).executeAsOneOrNull()) {
                                is AutomaticLiquidityPurchasePayment -> {
                                    val autoLiquidityPayment1 = autoLiquidityPayment.copy(incomingPaymentReceivedAt = paymentInDb1.completedAt)
                                    database.paymentsOutgoingQueries.update(
                                        id = autoLiquidityPayment1.id,
                                        completed_at = autoLiquidityPayment1.completedAt,
                                        succeeded_at = autoLiquidityPayment1.succeededAt,
                                        data = autoLiquidityPayment1
                                    )
                                }
                                else -> {}
                            }
                        }
                        didSaveWalletPayment(paymentInDb1.id, database)
                    }
                    null -> error("missing payment for payment_hash=$paymentHash")
                }
            }
        }
    }

    override suspend fun listLightningExpiredPayments(fromCreatedAt: Long, toCreatedAt: Long): List<LightningIncomingPayment> =
        withContext(Dispatchers.Default) {
            database.paymentsIncomingQueries.list(created_at_from = fromCreatedAt, created_at_to = toCreatedAt, offset = 0, limit = Long.MAX_VALUE)
                .executeAsList()
                .filterIsInstance<Bolt11IncomingPayment>()
                .filter { it.parts.isEmpty() && it.paymentRequest.isExpired() }
        }

    override suspend fun removeLightningIncomingPayment(paymentHash: ByteVector32): Boolean =
        withContext(Dispatchers.Default) {
            database.transactionWithResult {
                database.paymentsIncomingQueries.deleteByPaymentHash(payment_hash = paymentHash)
                didDeleteWalletPayment(paymentHash.deriveUUID(), database)
                database.paymentsIncomingQueries.changes().executeAsOne() != 0L
            }
        }
}