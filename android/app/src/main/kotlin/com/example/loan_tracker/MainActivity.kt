// MainActivity for Loan Tracker.
// Extends FlutterActivity to host the Flutter UI.
// On resume, forces a refresh of the home-screen widget so the balance
// and progress always reflect the latest payment data.

package com.example.loan_tracker

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    override fun onResume() {
        super.onResume()
        // Refresh the home-screen widget with the latest SharedPreferences
        // values written by Flutter's WidgetService.
        LoanWidgetProvider.pushUpdate(this)
    }
}
