package com.example.safeguard

import android.app.Application
import android.content.Context

class SosWidgetApp : Application() {
    companion object {
        var context: Context? = null
    }

    override fun onCreate() {
        super.onCreate()
        context = applicationContext
    }
}