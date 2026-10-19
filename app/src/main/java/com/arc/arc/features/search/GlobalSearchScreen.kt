package com.arc.arc.features.search

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.TrendingDown
import androidx.compose.material.icons.automirrored.filled.TrendingUp
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.arc.arc.core.designsystem.theme.ArcTheme
import com.arc.arc.core.model.HabitModel
import com.arc.arc.core.model.TaskModel
import com.arc.arc.core.model.TransactionModel
import com.arc.arc.core.utilities.CurrencyFormatter
import java.text.SimpleDateFormat
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GlobalSearchScreen(
    viewModel: GlobalSearchViewModel,
    onBackClick: () -> Unit = {},
    onTaskClick: (TaskModel) -> Unit = {},
    onHabitClick: (HabitModel) -> Unit = {},
    onTransactionClick: (TransactionModel) -> Unit = {},
) {
    val uiState by viewModel.uiState.collectAsState()

    Scaffold(
        containerColor = ArcTheme.colors.background,
        topBar = {
            TopAppBar(
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = ArcTheme.colors.surface,
                    titleContentColor = ArcTheme.colors.textPrimary,
                    navigationIconContentColor = ArcTheme.colors.textPrimary,
                ),
                navigationIcon = {
                    IconButton(onClick = onBackClick) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back",
                            tint = ArcTheme.colors.textPrimary,
                        )
                    }
                },
                title = {
                    TextField(
                        value = uiState.query,
                        onValueChange = { viewModel.onQueryChanged(it) },
                        placeholder = {
                            Text(
                                text = "Search tasks, habits, transactions...",
                                color = ArcTheme.colors.textSecondary,
                                fontSize = 15.sp,
                            )
                        },
                        singleLine = true,
                        colors = TextFieldDefaults.colors(
                            focusedContainerColor = Color.Transparent,
                            unfocusedContainerColor = Color.Transparent,
                            disabledContainerColor = Color.Transparent,
                            focusedIndicatorColor = Color.Transparent,
                            unfocusedIndicatorColor = Color.Transparent,
                            focusedTextColor = ArcTheme.colors.textPrimary,
                            unfocusedTextColor = ArcTheme.colors.textPrimary,
                            cursorColor = ArcTheme.colors.accent,
                        ),
                        trailingIcon = {
                            if (uiState.query.isNotEmpty()) {
                                IconButton(onClick = { viewModel.clearQuery() }) {
                                    Icon(
                                        imageVector = Icons.Default.Clear,
                                        contentDescription = "Clear search",
                                        tint = ArcTheme.colors.textSecondary,
                                        modifier = Modifier.size(20.dp),
                                    )
                                }
                            }
                        },
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            )
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            // Filter chips row
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(ArcTheme.colors.surface)
                    .horizontalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                SearchFilter.values().forEach { filter ->
                    val isSelected = uiState.activeFilter == filter
                    val count = when (filter) {
                        SearchFilter.ALL -> uiState.totalMatches
                        SearchFilter.TASKS -> uiState.rawTaskCount
                        SearchFilter.HABITS -> uiState.rawHabitCount
                        SearchFilter.TRANSACTIONS -> uiState.rawTransactionCount
                    }
                    val labelText = if (uiState.query.isNotBlank()) "${filter.label} ($count)" else filter.label

                    FilterChip(
                        selected = isSelected,
                        onClick = { viewModel.onFilterSelected(filter) },
                        label = {
                            Text(
                                text = labelText,
                                fontSize = 13.sp,
                                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                            )
                        },
                        colors = FilterChipDefaults.filterChipColors(
                            containerColor = ArcTheme.colors.card,
                            labelColor = ArcTheme.colors.textSecondary,
                            selectedContainerColor = ArcTheme.colors.accent.copy(alpha = 0.2f),
                            selectedLabelColor = ArcTheme.colors.accent,
                        ),
                        border = FilterChipDefaults.filterChipBorder(
                            enabled = true,
                            selected = isSelected,
                            borderColor = ArcTheme.colors.borderSubtle,
                            selectedBorderColor = ArcTheme.colors.accent,
                        ),
                    )
                }
            }

            // Results / Empty states
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 16.dp),
            ) {
                when {
                    uiState.isSearching -> {
                        CircularProgressIndicator(
                            color = ArcTheme.colors.accent,
                            modifier = Modifier.align(Alignment.Center),
                        )
                    }
                    uiState.query.isBlank() -> {
                        EmptyQueryPrompt(modifier = Modifier.align(Alignment.Center))
                    }
                    uiState.totalMatches == 0 -> {
                        NoResultsPrompt(
                            query = uiState.query,
                            modifier = Modifier.align(Alignment.Center),
                        )
                    }
                    else -> {
                        SearchResultsList(
                            tasks = uiState.matchedTasks,
                            habits = uiState.matchedHabits,
                            transactions = uiState.matchedTransactions,
                            onTaskClick = onTaskClick,
                            onHabitClick = onHabitClick,
                            onTransactionClick = onTransactionClick,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun EmptyQueryPrompt(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(
            imageVector = Icons.Default.Search,
            contentDescription = null,
            tint = ArcTheme.colors.textSecondary.copy(alpha = 0.6f),
            modifier = Modifier.size(56.dp),
        )
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = "Search across all modules",
            style = ArcTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = ArcTheme.colors.textPrimary,
        )
        Spacer(modifier = Modifier.height(6.dp))
        Text(
            text = "Search tasks, habits, and transactions by title, category, or notes",
            style = ArcTheme.typography.bodySmall,
            color = ArcTheme.colors.textSecondary,
        )
    }
}

@Composable
private fun NoResultsPrompt(
    query: String,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(
            imageVector = Icons.Default.Search,
            contentDescription = null,
            tint = ArcTheme.colors.textSecondary.copy(alpha = 0.6f),
            modifier = Modifier.size(56.dp),
        )
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = "No results found for \"$query\"",
            style = ArcTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = ArcTheme.colors.textPrimary,
        )
        Spacer(modifier = Modifier.height(6.dp))
        Text(
            text = "Try different keywords or adjusting the filter category",
            style = ArcTheme.typography.bodySmall,
            color = ArcTheme.colors.textSecondary,
        )
    }
}

@Composable
private fun SearchResultsList(
    tasks: List<TaskModel>,
    habits: List<HabitModel>,
    transactions: List<TransactionModel>,
    onTaskClick: (TaskModel) -> Unit,
    onHabitClick: (HabitModel) -> Unit,
    onTransactionClick: (TransactionModel) -> Unit,
) {
    LazyColumn(
        contentPadding = PaddingValues(vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
        modifier = Modifier.fillMaxSize(),
    ) {
        if (tasks.isNotEmpty()) {
            item {
                SectionHeader("Tasks (${tasks.size})")
            }
            items(tasks, key = { "task_${it.id}" }) { task ->
                TaskSearchCard(task = task, onClick = { onTaskClick(task) })
            }
        }

        if (habits.isNotEmpty()) {
            item {
                Spacer(modifier = Modifier.height(8.dp))
                SectionHeader("Habits (${habits.size})")
            }
            items(habits, key = { "habit_${it.id}" }) { habit ->
                HabitSearchCard(habit = habit, onClick = { onHabitClick(habit) })
            }
        }

        if (transactions.isNotEmpty()) {
            item {
                Spacer(modifier = Modifier.height(8.dp))
                SectionHeader("Transactions (${transactions.size})")
            }
            items(transactions, key = { "tx_${it.id}" }) { tx ->
                TransactionSearchCard(transaction = tx, onClick = { onTransactionClick(tx) })
            }
        }
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        text = title,
        style = ArcTheme.typography.titleSmall,
        fontWeight = FontWeight.Bold,
        color = ArcTheme.colors.accent,
        modifier = Modifier.padding(horizontal = 4.dp, vertical = 4.dp),
    )
}

@Composable
private fun TaskSearchCard(
    task: TaskModel,
    onClick: () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(ArcTheme.colors.card)
            .border(1.dp, ArcTheme.colors.borderSubtle, RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(14.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth()
        ) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(ArcTheme.colors.accent.copy(alpha = 0.15f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Default.CheckCircle,
                    contentDescription = null,
                    tint = ArcTheme.colors.accent,
                    modifier = Modifier.size(18.dp),
                )
            }
            Spacer(modifier = Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = task.title,
                    style = ArcTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Bold,
                    color = ArcTheme.colors.textPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = "${task.category} • Priority: ${task.displayPriority}",
                    style = ArcTheme.typography.bodySmall,
                    color = ArcTheme.colors.textSecondary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

@Composable
private fun HabitSearchCard(
    habit: HabitModel,
    onClick: () -> Unit,
) {
    val habitColor = remember(habit.colorValue) {
        if (habit.colorValue != 0L) Color(habit.colorValue) else Color(0xFF6C5CE7)
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(ArcTheme.colors.card)
            .border(1.dp, ArcTheme.colors.borderSubtle, RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(14.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth()
        ) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(habitColor.copy(alpha = 0.15f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Default.Star,
                    contentDescription = null,
                    tint = habitColor,
                    modifier = Modifier.size(18.dp),
                )
            }
            Spacer(modifier = Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = habit.name,
                    style = ArcTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Bold,
                    color = ArcTheme.colors.textPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = habit.category,
                    style = ArcTheme.typography.bodySmall,
                    color = ArcTheme.colors.textSecondary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

@Composable
private fun TransactionSearchCard(
    transaction: TransactionModel,
    onClick: () -> Unit,
) {
    val isIncome = transaction.isIncome
    val iconColor = if (isIncome) Color(0xFF00B894) else ArcTheme.colors.danger
    val formattedAmount = (if (isIncome) "+" else "-") + CurrencyFormatter.formatPaise(transaction.amountPaise)
    val dateStr = remember(transaction.date) {
        SimpleDateFormat("MMM d, yyyy", Locale.US).format(transaction.date)
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(ArcTheme.colors.card)
            .border(1.dp, ArcTheme.colors.borderSubtle, RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(14.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth()
        ) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(iconColor.copy(alpha = 0.15f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = if (isIncome) Icons.AutoMirrored.Filled.TrendingUp else Icons.AutoMirrored.Filled.TrendingDown,
                    contentDescription = null,
                    tint = iconColor,
                    modifier = Modifier.size(18.dp),
                )
            }
            Spacer(modifier = Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = transaction.category,
                    style = ArcTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Bold,
                    color = ArcTheme.colors.textPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = transaction.notes.ifBlank { dateStr },
                    style = ArcTheme.typography.bodySmall,
                    color = ArcTheme.colors.textSecondary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Text(
                text = formattedAmount,
                style = ArcTheme.typography.bodyMedium,
                fontWeight = FontWeight.Bold,
                color = iconColor,
            )
        }
    }
}
