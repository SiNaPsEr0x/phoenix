/*
 * Copyright 2022 ACINQ SAS
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

package fr.acinq.phoenix.android.settings

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import fr.acinq.phoenix.android.R
import fr.acinq.phoenix.android.components.*
import fr.acinq.phoenix.android.components.dialogs.Dialog
import fr.acinq.phoenix.android.components.inputs.TextInput
import fr.acinq.phoenix.android.components.prefs.ListPreferenceButton
import fr.acinq.phoenix.android.components.prefs.PreferenceItem
import fr.acinq.phoenix.android.components.settings.Setting
import fr.acinq.phoenix.android.components.settings.SettingSwitch
import fr.acinq.phoenix.android.navController
import fr.acinq.phoenix.android.userPrefs
import fr.acinq.phoenix.android.utils.datastore.SwapAddressFormat
import fr.acinq.phoenix.data.lnurl.LnurlAuth
import kotlinx.coroutines.launch
import java.text.NumberFormat
import kotlin.time.Duration.Companion.days
import kotlin.time.Duration.Companion.hours

@Composable
fun PaymentSettingsView(
    initialShowLnurlAuthSchemeDialog: Boolean = false,
) {
    val nc = navController
    val scope = rememberCoroutineScope()
    val userPrefs = userPrefs

    var showDescriptionDialog by rememberSaveable { mutableStateOf(false) }

    val invoiceDefaultDesc by userPrefs.getInvoiceDefaultDesc.collectAsState(initial = "")
    val swapAddressFormatState = userPrefs.getSwapAddressFormat.collectAsState(initial = null)

    DefaultScreenLayout {
        DefaultScreenHeader(
            onBackClick = { nc.popBackStack() },
            title = stringResource(id = R.string.paymentsettings_title),
        )

        CardHeader(text = stringResource(id = R.string.paymentsettings_category_incoming))
        Card {
            Setting(
                title = stringResource(id = R.string.paymentsettings_defaultdesc_title),
                description = invoiceDefaultDesc.ifEmpty { stringResource(id = R.string.paymentsettings_defaultdesc_none) },
                onClick = { showDescriptionDialog = true }
            )
            Bolt11ExpiryPreference()
            val swapAddressFormat = swapAddressFormatState.value
            if (swapAddressFormat != null) {
                val schemes = listOf(
                    PreferenceItem(
                        item = SwapAddressFormat.TAPROOT_ROTATE,
                        title = stringResource(id = R.string.paymentsettings_swap_format_taproot_title),
                        description = stringResource(id = R.string.paymentsettings_swap_format_taproot_desc)
                    ),
                    PreferenceItem(
                        item = SwapAddressFormat.LEGACY,
                        title = stringResource(id = R.string.paymentsettings_swap_format_legacy_title),
                        description = stringResource(id = R.string.paymentsettings_swap_format_legacy_desc)
                    ),
                )
                ListPreferenceButton(
                    title = stringResource(id = R.string.paymentsettings_swap_format_title),
                    subtitle = {
                        when (swapAddressFormat) {
                            SwapAddressFormat.LEGACY -> Text(text = stringResource(id = R.string.paymentsettings_swap_format_legacy_title))
                            SwapAddressFormat.TAPROOT_ROTATE -> Text(text = stringResource(id = R.string.paymentsettings_swap_format_taproot_title))
                        }
                    },
                    enabled = true,
                    selectedItem = swapAddressFormat,
                    preferences = schemes,
                    onPreferenceSubmit = {
                        scope.launch { userPrefs.saveSwapAddressFormat(it.item) }
                    },
                    initialShowDialog = false
                )
            }

            SettingSwitch(
                title = "Block BOLT12 payments from unknown sources",
                description = "\uD83D\uDEA7 Coming soon",
                enabled = false,
                isChecked = false,
                onCheckChangeAttempt = {}
            )
        }

        val isOverpaymentEnabled by userPrefs.getIsOverpaymentEnabled.collectAsState(initial = false)
        CardHeader(text = stringResource(id = R.string.paymentsettings_category_outgoing))
        Card {
            SettingSwitch(
                title = stringResource(id = R.string.paymentsettings_overpayment_title),
                description = stringResource(id = if (isOverpaymentEnabled) R.string.paymentsettings_overpayment_enabled else R.string.paymentsettings_overpayment_disabled),
                enabled = true,
                isChecked = isOverpaymentEnabled,
                onCheckChangeAttempt = {
                    scope.launch { userPrefs.saveIsOverpaymentEnabled(it) }
                }
            )
        }

        val prefLnurlAuthSchemeState = userPrefs.getLnurlAuthScheme.collectAsState(initial = null)
        val prefLnurlAuthScheme = prefLnurlAuthSchemeState.value
        if (prefLnurlAuthScheme != null) {
            CardHeader(text = stringResource(id = R.string.paymentsettings_category_lnurl))
            Card {
                val schemes = listOf<PreferenceItem<LnurlAuth.Scheme>>(
                    PreferenceItem(
                        item = LnurlAuth.Scheme.DEFAULT_SCHEME,
                        title = stringResource(id = R.string.lnurl_auth_scheme_default),
                        description = stringResource(id = R.string.lnurl_auth_scheme_default_desc)
                    ),
                    PreferenceItem(
                        item = LnurlAuth.Scheme.ANDROID_LEGACY_SCHEME,
                        title = stringResource(id = R.string.lnurl_auth_scheme_legacy),
                        description = stringResource(id = R.string.lnurl_auth_scheme_legacy_desc)
                    ),
                )
                ListPreferenceButton(
                    title = stringResource(id = R.string.paymentsettings_lnurlauth_scheme_title),
                    subtitle = {
                        when (prefLnurlAuthScheme) {
                            LnurlAuth.Scheme.ANDROID_LEGACY_SCHEME -> Text(text = stringResource(id = R.string.lnurl_auth_scheme_legacy))
                            LnurlAuth.Scheme.DEFAULT_SCHEME -> Text(text = stringResource(id = R.string.lnurl_auth_scheme_default))
                            else -> Text(text = stringResource(id = R.string.utils_unknown))
                        }
                    },
                    enabled = true,
                    selectedItem = prefLnurlAuthScheme,
                    preferences = schemes,
                    onPreferenceSubmit = {
                        scope.launch { userPrefs.saveLnurlAuthScheme(it.item) }
                    },
                    initialShowDialog = initialShowLnurlAuthSchemeDialog
                )
            }
        }
    }

    if (showDescriptionDialog) {
        DefaultDescriptionInvoiceDialog(
            description = invoiceDefaultDesc,
            onDismiss = { showDescriptionDialog = false },
            onConfirm = {
                scope.launch { userPrefs.saveInvoiceDefaultDesc(it) }
                showDescriptionDialog = false
            }
        )
    }
}

@Composable
private fun Bolt11ExpiryPreference() {
    val scope = rememberCoroutineScope()
    val userPrefs = userPrefs
    val preferences = listOf(
        PreferenceItem(item = 1.hours.inWholeSeconds, title = stringResource(id = R.string.paymentsettings_expiry_one_hour)),
        PreferenceItem(item = 1.days.inWholeSeconds, title = stringResource(id = R.string.paymentsettings_expiry_one_day)),
        PreferenceItem(item = 7.days.inWholeSeconds, title = stringResource(id = R.string.paymentsettings_expiry_one_week)),
        PreferenceItem(item = 14.days.inWholeSeconds, title = stringResource(id = R.string.paymentsettings_expiry_two_weeks)),
        PreferenceItem(item = 21.days.inWholeSeconds, title = stringResource(id = R.string.paymentsettings_expiry_three_weeks)),
    )
    val expiry by userPrefs.getInvoiceDefaultExpiry.collectAsState(initial = null)
    expiry?.let {
        ListPreferenceButton(
            title = stringResource(id = R.string.paymentsettings_expiry_title),
            subtitle = {
                Text(text = when (it) {
                    1.hours.inWholeSeconds -> stringResource(id = R.string.paymentsettings_expiry_one_hour)
                    1.days.inWholeSeconds -> stringResource(id = R.string.paymentsettings_expiry_one_day)
                    7.days.inWholeSeconds -> stringResource(id = R.string.paymentsettings_expiry_one_week)
                    14.days.inWholeSeconds -> stringResource(id = R.string.paymentsettings_expiry_two_weeks)
                    21.days.inWholeSeconds -> stringResource(id = R.string.paymentsettings_expiry_three_weeks)
                    else -> stringResource(id = R.string.paymentsettings_expiry_value, NumberFormat.getInstance().format(expiry))
                })
            },
            selectedItem = it,
            preferences = preferences,
            enabled = true,
            onPreferenceSubmit = {
                scope.launch {
                    userPrefs.saveInvoiceDefaultExpiry(it.item)
                }
            }
        )
    }
}

@Composable
private fun DefaultDescriptionInvoiceDialog(
    description: (String),
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit,
) {
    var paymentDescription by rememberSaveable { mutableStateOf(description) }

    Dialog(
        onDismiss = onDismiss,
        title = stringResource(id = R.string.paymentsettings_defaultdesc_dialog_title),
        buttons = {
            Button(onClick = onDismiss, text = stringResource(id = R.string.btn_cancel))
            Button(
                onClick = { onConfirm(paymentDescription) },
                text = stringResource(id = R.string.btn_ok)
            )
        }
    ) {
        Column(Modifier.padding(horizontal = 24.dp)) {
            Text(text = stringResource(id = R.string.paymentsettings_defaultdesc_dialog_description))
            Spacer(Modifier.height(24.dp))
            TextInput(
                modifier = Modifier.fillMaxWidth(),
                text = paymentDescription,
                staticLabel = stringResource(id = R.string.paymentsettings_defaultdesc_dialog_label),
                onTextChange = { paymentDescription = it },
                maxLines = 3,
                maxChars = 180,
            )
        }
    }
}
