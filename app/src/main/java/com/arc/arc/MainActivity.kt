package com.arc.arc

import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.fragment.app.FragmentActivity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import com.arc.arc.core.datastore.AppPreferences
import com.arc.arc.core.designsystem.theme.ArcTheme
import com.arc.arc.features.tasks.TasksRoute
import com.arc.arc.navigation.ArcNavHost

class MainActivity : FragmentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        val container = (application as ArcApplication).container
        lifecycle.addObserver(container.vaultLifecycleManager)

        setContent {
            val preferences by container.preferencesDataStore.preferencesFlow.collectAsState(
                initial = AppPreferences()
            )

            val isDark = when (preferences.themeMode) {
                "dark" -> true
                "light" -> false
                else -> isSystemInDarkTheme()
            }

            ArcTheme(darkTheme = isDark) {
                ArcNavHost(
                    container = container,
                    tasksContent = {
                        TasksRoute(container = container)
                    },
                )
            }
        }
    }
}
