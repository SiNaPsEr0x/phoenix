/*
 * Copyright 2025 ACINQ SAS
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

@file:Suppress("DEPRECATION")

package fr.acinq.phoenix.android.payments.details.splash

import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import fr.acinq.lightning.db.LegacyPayToOpenIncomingPayment
import fr.acinq.lightning.utils.UUID
import fr.acinq.lightning.utils.msat
import fr.acinq.lightning.utils.sat
import fr.acinq.lightning.utils.sum
import fr.acinq.phoenix.android.LocalBitcoinUnits
import fr.acinq.phoenix.android.R
import fr.acinq.phoenix.android.components.SplashLabelRow
import fr.acinq.phoenix.android.utils.converters.AmountFormatter.toPrettyString
import fr.acinq.phoenix.android.utils.converters.MSatDisplayPolicy
import fr.acinq.phoenix.android.utils.extensions.smartDescription
import fr.acinq.phoenix.data.WalletPaymentMetadata
import fr.acinq.phoenix.utils.extensions.state

@Composable
fun SplashIncomingLegacyPayToOpen(
    payment: LegacyPayToOpenIncomingPayment,
    metadata: WalletPaymentMetadata,
    onMetadataDescriptionUpdate: (UUID, String?) -> Unit,
) {
    SplashAmount(amount = payment.amount, state = payment.state(), isOutgoing = false)
    SplashDescription(
        description = payment.smartDescription(),
        userDescription = metadata.userDescription,
        paymentId = payment.id,
        onMetadataDescriptionUpdate = onMetadataDescriptionUpdate,
    )
    SplashFee(payment)
}

@Composable
private fun SplashFee(payment: LegacyPayToOpenIncomingPayment) {
    val serviceFee = payment.parts.filterIsInstance<LegacyPayToOpenIncomingPayment.Part.OnChain>().map { it.serviceFee }.sum()
    if (serviceFee > 0.msat) {
        Spacer(modifier = Modifier.height(8.dp))
        SplashLabelRow(
            label = stringResource(id = R.string.paymentdetails_service_fees_label),
            helpMessage = stringResource(R.string.paymentdetails_service_fees_desc)
        ) {
            Text(text = serviceFee.toPrettyString(LocalBitcoinUnits.current.primary, withUnit = true, mSatDisplayPolicy = MSatDisplayPolicy.SHOW))
        }
    }

    val miningFee = payment.parts.filterIsInstance<LegacyPayToOpenIncomingPayment.Part.OnChain>().map { it.miningFee }.sum()
    if (miningFee > 0.sat) {
        Spacer(modifier = Modifier.height(8.dp))
        SplashLabelRow(
            label = stringResource(id = R.string.paymentdetails_funding_fees_label),
            helpMessage = stringResource(R.string.paymentdetails_funding_fees_desc)
        ) {
            Text(text = miningFee.toPrettyString(LocalBitcoinUnits.current.primary, withUnit = true, mSatDisplayPolicy = MSatDisplayPolicy.HIDE))
        }
    }
}
