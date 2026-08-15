package com.novaturients.pdfhawk

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.novaturients.pdfhawk/intent"
    private var methodChannel: MethodChannel? = null
    private var initialPdfPath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            if (call.method == "getInitialPdfPath") {
                val path = initialPdfPath
                initialPdfPath = null
                result.success(path)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent, isInitial = true)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent, isInitial = false)
    }

    private fun handleIntent(intent: Intent?, isInitial: Boolean) {
        if (intent == null) return
        val action = intent.action
        val type = intent.type

        var targetUri: Uri? = null

        if (Intent.ACTION_VIEW == action) {
            targetUri = intent.data
        } else if (Intent.ACTION_SEND == action && type != null) {
            if (type == "application/pdf" || type.contains("pdf")) {
                @Suppress("DEPRECATION")
                targetUri = intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
            }
        }

        if (targetUri != null) {
            val localPath = resolveAndCacheUri(targetUri)
            if (localPath != null) {
                if (isInitial) {
                    initialPdfPath = localPath
                } else {
                    methodChannel?.invokeMethod("onPdfOpened", localPath)
                }
            }
        }
    }

    private fun resolveAndCacheUri(uri: Uri): String? {
        return try {
            if (uri.scheme == "file") {
                val file = uri.path?.let { File(it) }
                if (file != null && file.exists()) {
                    return file.absolutePath
                }
            }

            var fileName = "opened_document.pdf"
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (nameIndex != -1 && cursor.moveToFirst()) {
                    val name = cursor.getString(nameIndex)
                    if (!name.isNullOrBlank()) {
                        fileName = name
                    }
                }
            }

            if (!fileName.lowercase().endsWith(".pdf")) {
                fileName += ".pdf"
            }

            val cacheFolder = File(cacheDir, "opened_pdfs")
            if (!cacheFolder.exists()) {
                cacheFolder.mkdirs()
            }

            val outputFile = File(cacheFolder, "${System.currentTimeMillis()}_$fileName")
            contentResolver.openInputStream(uri)?.use { inputStream ->
                FileOutputStream(outputFile).use { outputStream ->
                    inputStream.copyTo(outputStream)
                }
            }

            if (outputFile.exists() && outputFile.length() > 0) {
                outputFile.absolutePath
            } else {
                null
            }
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}
