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

package fr.acinq.phoenix.db

import androidx.sqlite.db.SupportSQLiteDatabase
import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.android.AndroidSqliteDriver
import fr.acinq.bitcoin.Chain
import fr.acinq.phoenix.db.migrations.v10.AfterVersion10
import fr.acinq.phoenix.db.migrations.v11.AfterVersion11
import fr.acinq.phoenix.db.sqldelight.AppDatabase
import fr.acinq.phoenix.db.sqldelight.ChannelsDatabase
import fr.acinq.phoenix.db.sqldelight.PaymentsDatabase
import fr.acinq.phoenix.utils.PlatformContext

actual fun createChannelsDbDriver(ctx: PlatformContext, fileName: String): SqlDriver {
    return AndroidSqliteDriver(
        schema = ChannelsDatabase.Schema,
        context = ctx.applicationContext,
        name = fileName,
        callback = object : AndroidSqliteDriver.Callback(schema = ChannelsDatabase.Schema) {
            override fun onConfigure(db: SupportSQLiteDatabase) {
                super.onConfigure(db)
                db.setForeignKeyConstraintsEnabled(true)
            }
        }
    )
}

actual fun createPaymentsDbDriver(ctx: PlatformContext, fileName: String, onError: (String) -> Unit): SqlDriver {
    return AndroidSqliteDriver(
        schema = PaymentsDatabase.Schema,
        context = ctx.applicationContext,
        name = fileName,
        callback = object : AndroidSqliteDriver.Callback(
            schema = PaymentsDatabase.Schema,
            AfterVersion10(onError),
            AfterVersion11(onError),
        ) {
            override fun onConfigure(db: SupportSQLiteDatabase) {
                super.onConfigure(db)
                db.setForeignKeyConstraintsEnabled(true)
            }
        }
    )
}

actual fun createAppDbDriver(ctx: PlatformContext): SqlDriver {
    return AndroidSqliteDriver(AppDatabase.Schema, ctx.applicationContext, "appdb.sqlite", callback = object : AndroidSqliteDriver.Callback(schema = AppDatabase.Schema) {
        override fun onConfigure(db: SupportSQLiteDatabase) {
            super.onConfigure(db)
            db.setForeignKeyConstraintsEnabled(true)
        }
    })
}