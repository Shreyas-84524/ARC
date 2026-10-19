package com.arc.arc.navigation

import com.arc.arc.core.auth.AuthState
import com.arc.arc.core.auth.DevFakeAuthRepository
import com.arc.arc.core.designsystem.components.ArcNavTab
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Validates navigation tab mapping, route identifiers, and auth state routing logic.
 */
class NavigationStateTest {

    @Test
    fun testTabDefinitionsAndRoutesMatchFlutterShell() {
        assertEquals("dashboard", ArcNavTab.DASHBOARD.route)
        assertEquals("tasks", ArcNavTab.TASKS.route)
        assertEquals("habits", ArcNavTab.HABITS.route)
        assertEquals("money", ArcNavTab.MONEY.route)

        assertEquals("Dashboard", ArcNavTab.DASHBOARD.title)
        assertEquals("Tasks", ArcNavTab.TASKS.title)
        assertEquals("Habits", ArcNavTab.HABITS.title)
        assertEquals("Money", ArcNavTab.MONEY.title)
        assertEquals("Vault", ArcNavTab.VAULT.title)
        assertEquals("vault", ArcNavTab.VAULT.route)
    }

    @Test
    fun testShellOverlayRoutes() {
        val routes = ShellOverlayRoute.values()
        assertEquals(3, routes.size)
        assertTrue(routes.contains(ShellOverlayRoute.NONE))
        assertTrue(routes.contains(ShellOverlayRoute.SEARCH))
        assertTrue(routes.contains(ShellOverlayRoute.SETTINGS))
    }

    @Test
    fun testAuthStateDeterminesNavigationDestination() {
        val repo = DevFakeAuthRepository()
        assertTrue(repo.authState.value is AuthState.Authenticated)

        val destination = when (repo.authState.value) {
            is AuthState.Authenticated -> "main_shell"
            is AuthState.Unauthenticated, is AuthState.Error -> "login"
            is AuthState.Initializing -> "splash"
        }
        assertEquals("main_shell", destination)
    }
}
