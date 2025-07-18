/*
 * Copyright 2021 ACINQ SAS
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

package fr.acinq.phoenix.android.components

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.*
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.layout.FirstBaseline
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import fr.acinq.bitcoin.TxId
import fr.acinq.phoenix.android.R
import fr.acinq.phoenix.android.business
import fr.acinq.phoenix.android.utils.copyToClipboard
import fr.acinq.phoenix.android.utils.mutedBgColor
import fr.acinq.phoenix.utils.BlockchainExplorer


/** A rounded button with a solid surface background and a muted outline. */
@Composable
fun BorderButton(
    modifier: Modifier = Modifier,
    text: String? = null,
    icon: Int? = null,
    iconTint: Color = MaterialTheme.colors.primary,
    shape: Shape = CircleShape,
    backgroundColor: Color = MaterialTheme.colors.surface,
    borderColor: Color = MaterialTheme.colors.primary,
    enabled: Boolean = true,
    enabledEffect: Boolean = true,
    space: Dp = 12.dp,
    maxLines: Int = Int.MAX_VALUE,
    textStyle: TextStyle = MaterialTheme.typography.button,
    padding: PaddingValues = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
    interactionSource: MutableInteractionSource = remember { MutableInteractionSource() },
    onClick: () -> Unit,
) {
    Button(
        text = text,
        icon = icon,
        iconTint = iconTint,
        enabled = enabled,
        enabledEffect = enabledEffect,
        space = space,
        onClick = onClick,
        shape = shape,
        backgroundColor = backgroundColor,
        border = BorderStroke(ButtonDefaults.OutlinedBorderSize, if (enabled) borderColor else borderColor.copy(alpha = 0.35f)),
        textStyle = textStyle,
        padding = padding,
        maxLines = maxLines,
        interactionSource = interactionSource,
        modifier = modifier
    )
}

/** A rounded button with a primary background color. */
@Composable
fun FilledButton(
    modifier: Modifier = Modifier,
    text: String? = null,
    icon: Int? = null,
    iconTint: Color = MaterialTheme.colors.onPrimary,
    maxLines: Int = Int.MAX_VALUE,
    enabled: Boolean = true,
    enabledEffect: Boolean = true,
    space: Dp = 12.dp,
    shape: Shape = CircleShape,
    textStyle: TextStyle = MaterialTheme.typography.button.copy(color = MaterialTheme.colors.onPrimary),
    padding: PaddingValues = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
    backgroundColor: Color = MaterialTheme.colors.primary,
    horizontalArrangement: Arrangement.Horizontal = Arrangement.Center,
    onClick: () -> Unit,
) {
    Button(
        text = text,
        icon = icon,
        iconTint = iconTint,
        maxLines = maxLines,
        enabled = enabled,
        enabledEffect = enabledEffect,
        space = space,
        onClick = onClick,
        shape = shape,
        backgroundColor = backgroundColor,
        textStyle = textStyle,
        padding = padding,
        modifier = modifier,
        horizontalArrangement = horizontalArrangement,
    )
}

@Composable
fun MutedFilledButton(
    modifier: Modifier = Modifier,
    text: String? = null,
    icon: Int? = null,
    iconTint: Color = MaterialTheme.colors.onSurface,
    maxLines: Int = Int.MAX_VALUE,
    enabled: Boolean = true,
    enabledEffect: Boolean = true,
    space: Dp = 12.dp,
    padding: PaddingValues = PaddingValues(12.dp),
    onClick: () -> Unit,
    horizontalArrangement: Arrangement.Horizontal = Arrangement.Center,
) {
    FilledButton(
        shape = RoundedCornerShape(12.dp),
        backgroundColor = mutedBgColor,
        textStyle = MaterialTheme.typography.button,
        iconTint = iconTint,
        modifier = modifier, text = text, icon = icon, maxLines = maxLines, enabled = enabled,
        enabledEffect = enabledEffect, space = space, padding = padding, onClick = onClick,
        horizontalArrangement = horizontalArrangement,
    )
}

@Composable
fun TransparentFilledButton(
    modifier: Modifier = Modifier,
    text: String? = null,
    textStyle: TextStyle = MaterialTheme.typography.button,
    icon: Int? = null,
    iconTint: Color = MaterialTheme.colors.onSurface,
    maxLines: Int = Int.MAX_VALUE,
    enabled: Boolean = true,
    enabledEffect: Boolean = true,
    space: Dp = 12.dp,
    padding: PaddingValues = PaddingValues(12.dp),
    onClick: () -> Unit,
) {
    FilledButton(
        shape = RoundedCornerShape(12.dp),
        backgroundColor = Color.Transparent,
        textStyle = textStyle,
        iconTint = iconTint,
        modifier = modifier, text = text, icon = icon, maxLines = maxLines, enabled = enabled,
        enabledEffect = enabledEffect, space = space, padding = padding, onClick = onClick,
    )
}

@Composable
fun SurfaceFilledButton(
    modifier: Modifier = Modifier,
    text: String? = null,
    textStyle: TextStyle = MaterialTheme.typography.button,
    icon: Int? = null,
    iconTint: Color = MaterialTheme.colors.onSurface,
    maxLines: Int = Int.MAX_VALUE,
    enabled: Boolean = true,
    enabledEffect: Boolean = true,
    space: Dp = 12.dp,
    padding: PaddingValues = PaddingValues(12.dp),
    onClick: () -> Unit,
) {
    FilledButton(
        shape = RoundedCornerShape(12.dp),
        backgroundColor = MaterialTheme.colors.surface,
        textStyle = textStyle,
        iconTint = iconTint,
        modifier = modifier, text = text, icon = icon, maxLines = maxLines, enabled = enabled,
        enabledEffect = enabledEffect, space = space, padding = padding, onClick = onClick,
    )
}

/** Button that looks like an inline link, should fit in with regular text views. */
@Composable
fun InlineButton(
    text: String,
    modifier: Modifier = Modifier,
    icon: Int? = null,
    fontSize: TextUnit = MaterialTheme.typography.body1.fontSize,
    iconSize: Dp = ButtonDefaults.IconSize,
    padding: PaddingValues = PaddingValues(horizontal = 2.dp, vertical = 1.dp),
    space: Dp = 6.dp,
    maxLines: Int = Int.MAX_VALUE,
    onClick: () -> Unit,
    onLongClick: (() -> Unit)? = null,
    onClickLabel: String? = null,
) {
    Button(
        text = text,
        icon = icon,
        iconSize = iconSize,
        modifier = modifier,
        padding = padding,
        space = space,
        onClickLabel = onClickLabel,
        onClick = onClick,
        onLongClick = onLongClick,
        backgroundColor = Color.Transparent,
        shape = RoundedCornerShape(6.dp),
        maxLines = maxLines,
        textStyle = MaterialTheme.typography.body1.copy(color = MaterialTheme.colors.primary, fontSize = fontSize, textDecoration = TextDecoration.Underline),
        horizontalArrangement = Arrangement.Start,
    )
}

/** For annotated string text param. */
@Composable
fun TextWithIcon(
    text: AnnotatedString,
    icon: Int,
    modifier: Modifier = Modifier,
    textStyle: TextStyle = LocalTextStyle.current,
    maxLines: Int = Int.MAX_VALUE,
    textOverflow: TextOverflow = TextOverflow.Clip,
    iconTint: Color = MaterialTheme.colors.onSurface,
    iconSize: Dp = ButtonDefaults.IconSize,
    padding: PaddingValues = PaddingValues(0.dp),
    space: Dp = 6.dp,
    alignBaseLine: Boolean = false
) {
    Row(
        modifier = modifier.padding(padding),
        verticalAlignment = if (alignBaseLine) Alignment.Top else Alignment.CenterVertically
    ) {
        Image(
            painter = painterResource(id = icon),
            contentDescription = "icon for $text",
            modifier = Modifier
                .size(iconSize)
                .then(if (alignBaseLine) Modifier.alignBy(FirstBaseline) else Modifier),
            colorFilter = ColorFilter.tint(iconTint)
        )
        Spacer(Modifier.width(space))
        Text(text, style = textStyle, modifier = if (alignBaseLine) Modifier.alignBy(FirstBaseline) else Modifier, maxLines = maxLines, overflow = textOverflow)
    }
}

@Composable
fun TextWithIcon(
    text: String,
    icon: Int,
    modifier: Modifier = Modifier,
    textStyle: TextStyle = LocalTextStyle.current,
    maxLines: Int = Int.MAX_VALUE,
    textOverflow: TextOverflow = TextOverflow.Clip,
    iconTint: Color? = null,
    iconSize: Dp = ButtonDefaults.IconSize,
    padding: PaddingValues = PaddingValues(0.dp),
    space: Dp = 6.dp,
    verticalAlignment: Alignment.Vertical = Alignment.CenterVertically,
) {
    Row(
        modifier = modifier.padding(padding),
        verticalAlignment = verticalAlignment
    ) {
        Image(
            painter = painterResource(id = icon),
            contentDescription = "icon for $text",
            modifier = Modifier
                .size(iconSize)
                .then(if (verticalAlignment == Alignment.Top) Modifier.offset(y = 2.dp) else Modifier),
            colorFilter = iconTint?.let { ColorFilter.tint(it) }
        )
        Spacer(Modifier.width(space))
        Text(text, style = textStyle, maxLines = maxLines, overflow = textOverflow)
    }
}

@Composable
fun PhoenixIcon(
    resourceId: Int,
    modifier: Modifier = Modifier,
    tint: Color = MaterialTheme.colors.onSurface
) {
    Image(
        painter = painterResource(id = resourceId),
        contentDescription = "icon",
        modifier = modifier,
        colorFilter = ColorFilter.tint(tint)
    )
}

/**
 * A very customisable button, by default using a square shape with a transparent bg.
 *
 * Most of the code is directly taken from Material's implementation of contained button: cf: [androidx.compose.material.ButtonKt.Button]
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun Button(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    onLongClick: (() -> Unit)? = null,
    text: String? = null,
    icon: Int? = null,
    iconTint: Color = MaterialTheme.colors.primary,
    iconSize: Dp = ButtonDefaults.IconSize,
    space: Dp = 12.dp,
    enabled: Boolean = true,
    enabledEffect: Boolean = true,
    maxLines: Int = Int.MAX_VALUE,
    textStyle: TextStyle = MaterialTheme.typography.button,
    padding: PaddingValues = PaddingValues(16.dp),
    horizontalArrangement: Arrangement.Horizontal = Arrangement.Center,
    interactionSource: MutableInteractionSource = remember { MutableInteractionSource() },
    shape: Shape = RectangleShape,
    border: BorderStroke? = null,
    elevation: ButtonElevation? = null,
    role: Role = Role.Button,
    backgroundColor: Color = Color.Unspecified, // transparent by default!
    onClickLabel: String? = null,
) {
    val colors = ButtonDefaults.buttonColors(
        backgroundColor = backgroundColor,
        disabledBackgroundColor = if (enabledEffect && backgroundColor != Color.Unspecified) backgroundColor.copy(alpha = 0.4f) else backgroundColor,
    )
    val contentColor by colors.contentColor(true)
    Surface(
        shape = shape,
        color = colors.backgroundColor(enabled).value,
        contentColor = colors.contentColor(enabled).value,
        border = border,
        elevation = elevation?.elevation(enabled, interactionSource)?.value ?: 0.dp,
        modifier = modifier
            .combinedClickable(
                onClick = onClick,
                onClickLabel = onClickLabel,
                onLongClick = onLongClick,
                onLongClickLabel = null,
                onDoubleClick = null,
                enabled = enabled,
                role = role,
                interactionSource = interactionSource,
                indication = null, // use [LocalIndication.current] to ignore the button's shape.
            )
            .then(
                if (text == null && icon != null) {
                    Modifier.defaultMinSize(42.dp)
                } else {
                    Modifier
                }
            )
    ) {
        CompositionLocalProvider(LocalContentAlpha provides contentColor.alpha) {
            ProvideTextStyle(value = textStyle) {
                Row(
                    Modifier
                        .defaultMinSize(
                            minWidth = 0.dp,
                            minHeight = 0.dp
                        )
                        .indication(interactionSource, LocalIndication.current)
                        .padding(padding)
                        .alpha(
                            if (!enabled && enabledEffect) {
                                if (backgroundColor == Color.Unspecified) 0.3f else 0.65f
                            } else {
                                1f
                            }
                        ),
                    horizontalArrangement = horizontalArrangement,
                    verticalAlignment = Alignment.CenterVertically,
                    content = {
                        if (text != null && icon != null) {
                            TextWithIcon(
                                text = text,
                                icon = icon, iconTint = iconTint, iconSize = iconSize,
                                space = space,
                                maxLines = maxLines, textOverflow = TextOverflow.Ellipsis
                            )
                        } else if (text != null) {
                            Text(text = text, maxLines = maxLines, overflow = TextOverflow.Ellipsis)
                        } else if (icon != null) {
                            PhoenixIcon(resourceId = icon, tint = iconTint)
                        }
                    }
                )
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun Clickable(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    onLongClick: (() -> Unit)? = null,
    textStyle: TextStyle = MaterialTheme.typography.button,
    border: BorderStroke? = null,
    backgroundColor: Color = Color.Unspecified, // transparent by default!
    shape: Shape = RectangleShape,
    clickDescription: String = "",
    internalPadding: PaddingValues = PaddingValues(0.dp),
    indication: Indication? = LocalIndication.current,
    interactionSource: MutableInteractionSource = remember { MutableInteractionSource() },
    content: @Composable () -> Unit,
) {
    val colors = ButtonDefaults.buttonColors(
        backgroundColor = backgroundColor,
        contentColor = LocalContentColor.current,
    )
    val contentColor by colors.contentColor(true)
    Surface(
        shape = shape,
        color = backgroundColor,
        border = border,
        contentColor = contentColor,
        elevation = 0.dp,
        modifier = modifier
            .clip(shape)
            .combinedClickable(
                onClick = onClick,
                onLongClick = onLongClick,
                onLongClickLabel = null,
                onDoubleClick = null,
                enabled = enabled,
                role = Role.Button,
                onClickLabel = clickDescription,
                interactionSource = interactionSource,
                indication = indication
            )
            .padding(internalPadding)
    ) {
        CompositionLocalProvider(LocalContentAlpha provides contentColor.alpha) {
            ProvideTextStyle(value = textStyle) {
                content()
            }
        }
    }
}

@Composable
fun WebLink(
    text: String,
    url: String,
    modifier: Modifier = Modifier,
    fontSize: TextUnit = MaterialTheme.typography.body1.fontSize,
    iconSize: Dp = ButtonDefaults.IconSize,
    padding: PaddingValues = PaddingValues(horizontal = 2.dp, vertical = 1.dp),
    space: Dp = 8.dp,
    maxLines: Int = Int.MAX_VALUE,
    onClickLabel: String = stringResource(id = R.string.accessibility_link),
) {
    val context = LocalContext.current
    InlineButton(
        text = text,
        icon = R.drawable.ic_external_link,
        fontSize = fontSize,
        iconSize = iconSize,
        padding = padding,
        space = space,
        maxLines = maxLines,
        onClickLabel = onClickLabel,
        onClick = { openLink(context, url) },
        onLongClick = { copyToClipboard(context, text) },
        modifier = modifier,
    )
}

@Composable
fun AddressLinkButton(
    modifier: Modifier = Modifier,
    address: String,
) {
    WebLink(
        text = address,
        url = addressUrl(address = address),
        space = 4.dp,
        maxLines = 1,
        fontSize = 15.sp,
        iconSize = 14.dp,
        onClickLabel = stringResource(id = R.string.accessibility_address_explorer_link),
        modifier = modifier,
    )
}

@Composable
fun InlineTransactionLink(
    modifier: Modifier = Modifier,
    txId: TxId,
) {
    WebLink(
        text = txId.toString(),
        url = txUrl(txId = txId),
        space = 4.dp,
        maxLines = 1,
        fontSize = 15.sp,
        iconSize = 14.dp,
        onClickLabel = stringResource(id = R.string.accessibility_explorer_link),
        modifier = modifier,
    )
}

@Composable
fun txUrl(txId: TxId): String {
    return business.blockchainExplorer.txUrl(txId = txId, website = BlockchainExplorer.Website.MempoolSpace)
}

@Composable
fun addressUrl(address: String): String {
    return business.blockchainExplorer.addressUrl(addr = address, website = BlockchainExplorer.Website.MempoolSpace)
}

fun openLink(context: Context, link: String) {
    context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(link)))
}
