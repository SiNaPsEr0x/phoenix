/*
 * Copyright 2020 ACINQ SAS
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

package fr.acinq.phoenix.android.init

import android.content.Context
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.CreationExtras
import fr.acinq.phoenix.android.BuildConfig
import fr.acinq.phoenix.android.PhoenixApplication
import fr.acinq.phoenix.android.R
import fr.acinq.phoenix.android.components.*
import fr.acinq.phoenix.android.components.mvi.MVIControllerViewModel
import fr.acinq.phoenix.android.security.EncryptedSeed
import fr.acinq.phoenix.android.security.SeedManager
import fr.acinq.phoenix.android.utils.datastore.InternalDataRepository
import fr.acinq.phoenix.controllers.ControllerFactory
import fr.acinq.phoenix.controllers.InitializationController
import fr.acinq.phoenix.controllers.init.Initialization
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch


@Composable
fun InitWallet(
    onCreateWalletClick: () -> Unit,
    onRestoreWalletClick: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .fillMaxHeight(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        FilledButton(
            text = stringResource(id = R.string.initwallet_create),
            icon = R.drawable.ic_fire,
            onClick = onCreateWalletClick
        )
        Spacer(modifier = Modifier.height(16.dp))
        HSeparator(width = 80.dp)
        Spacer(modifier = Modifier.height(16.dp))
        BorderButton(
            text = stringResource(id = R.string.initwallet_restore),
            icon = R.drawable.ic_restore,
            onClick = onRestoreWalletClick
        )
    }
}


sealed class WritingSeedState {
    object Init : WritingSeedState()
    data class Writing(val mnemonics: List<String>) : WritingSeedState()
    data class WrittenToDisk(val encryptedSeed: EncryptedSeed) : WritingSeedState()
    data class Error(val e: Throwable) : WritingSeedState()
}

class InitViewModel(controller: InitializationController, val internalDataRepository: InternalDataRepository) : MVIControllerViewModel<Initialization.Model, Initialization.Intent>(controller) {

    /** State of the view */
    var writingState by mutableStateOf<WritingSeedState>(WritingSeedState.Init)
        private set

    /** State of the view */
    var restoreWalletState by mutableStateOf<RestoreWalletViewState>(RestoreWalletViewState.Disclaimer)

    var mnemonics by mutableStateOf(arrayOfNulls<String>(12))
        private set

    fun appendWordToMnemonic(word: String) {
        val index = mnemonics.indexOfFirst { it == null }
        if (index in 0..11) {
            mnemonics = mnemonics.copyOf().also { it[index] = word }
        }
    }

    fun removeWordsFromMnemonic(from: Int) {
        if (from in 0..11) {
            mnemonics = mnemonics.copyOf().also { it.fill(null, from) }
        }
    }

    /**
     * Attempts to write a seed on disk and updates the view model state. If a seed already
     * exists on disk, this method will not fail but it will not overwrite the existing file.
     *
     * @param isNewWallet when false, we will need to start the legacy app because this seed
     *          may be attached to a legacy wallet.
     */
    suspend fun writeSeed(
        context: Context,
        mnemonics: List<String>,
        isNewWallet: Boolean,
        onSeedWritten: () -> Unit
    ) = viewModelScope.launch(Dispatchers.IO) {
        if (writingState == WritingSeedState.Init) {
            log.debug("writing mnemonics to disk...")
            try {
                writingState = WritingSeedState.Writing(mnemonics)
                val existing = SeedManager.loadSeedFromDisk(context)
                if (existing == null) {
                    val encrypted = EncryptedSeed.V2.NoAuth.encrypt(EncryptedSeed.fromMnemonics(mnemonics))
                    SeedManager.writeSeedToDisk(context, encrypted)
                    writingState = WritingSeedState.WrittenToDisk(encrypted)
                    if (isNewWallet) {
                        log.info("wallet successfully created from new seed and written to disk")
                    } else {
                        log.info("wallet successfully restored from mnemonics and written to disk")
                    }
                } else {
                    log.warn("cannot overwrite existing seed=${existing.name()}")
                    writingState = WritingSeedState.WrittenToDisk(existing)
                }
                viewModelScope.launch(Dispatchers.Main) {
                    internalDataRepository.saveLastUsedAppCode(BuildConfig.VERSION_CODE)
                    delay(1000)
                    onSeedWritten()
                }
            } catch (e: Exception) {
                log.error("failed to write mnemonics to disk: ", e)
                writingState = WritingSeedState.Error(e)
            }
        }
    }

    class Factory(
        private val controllerFactory: ControllerFactory,
        private val getController: ControllerFactory.() -> InitializationController
    ) : ViewModelProvider.Factory {
        override fun <T : ViewModel> create(modelClass: Class<T>, extras: CreationExtras): T {
            val application = checkNotNull(extras[ViewModelProvider.AndroidViewModelFactory.APPLICATION_KEY] as? PhoenixApplication)
            @Suppress("UNCHECKED_CAST")
            return InitViewModel(controllerFactory.getController(), application.internalDataRepository) as T
        }
    }
}