package dev.dartlogic.currencygold

import android.app.Activity
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.Gravity
import android.view.WindowManager
import android.widget.*

class ConverterPopupActivity : Activity() {

    private val currencies = listOf("EUR", "USD", "TRY", "GBP", "CHF")
    private var rates = mutableMapOf<String, Double>()
    private var baseCurrency = "EUR"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Transparentes Popup-Fenster
        window.setBackgroundDrawableResource(android.R.color.transparent)
        window.setGravity(Gravity.CENTER)
        val params = window.attributes
        params.width = WindowManager.LayoutParams.MATCH_PARENT
        params.height = WindowManager.LayoutParams.WRAP_CONTENT
        params.dimAmount = 0.6f
        window.attributes = params
        window.addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)

        // Lade gespeicherte Kurse
        loadRates()

        setContentView(buildLayout())
    }

    private fun loadRates() {
        val prefs = getSharedPreferences("HomeWidgetPreferences", MODE_PRIVATE)
        // Wir speichern immer EUR-basierte Kurse
        rates["EUR"] = 1.0
        rates["USD"] = prefs.getString("eur_usd", null)?.toDoubleOrNull() ?: 1.08
        rates["TRY"] = prefs.getString("eur_try", null)?.toDoubleOrNull() ?: 36.0
        rates["GBP"] = prefs.getString("eur_gbp", null)?.toDoubleOrNull() ?: 0.856
    }

    private fun buildLayout(): android.view.View {
        val dp = resources.displayMetrics.density

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding((20 * dp).toInt(), (20 * dp).toInt(), (20 * dp).toInt(), (20 * dp).toInt())
            setBackgroundResource(R.drawable.popup_background)
        }

        // Titel
        val title = TextView(this).apply {
            text = "KaratExchange Rechner"
            textSize = 16f
            setTypeface(null, android.graphics.Typeface.BOLD)
            setTextColor(0xFFFFFFFF.toInt())
            setPadding(0, 0, 0, (12 * dp).toInt())
        }
        root.addView(title)

        // Basis-Währung Spinner
        val spinnerLabel = TextView(this).apply {
            text = "Basiswährung"
            textSize = 11f
            setTextColor(0xAAFFFFFF.toInt())
            setPadding(0, 0, 0, (4 * dp).toInt())
        }
        root.addView(spinnerLabel)

        val spinner = Spinner(this)
        val adapter = ArrayAdapter(this, android.R.layout.simple_spinner_item, currencies)
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
        spinner.adapter = adapter
        spinner.setSelection(currencies.indexOf(baseCurrency))
        root.addView(spinner)

        // Betrag Eingabe
        val amountLabel = TextView(this).apply {
            text = "Betrag"
            textSize = 11f
            setTextColor(0xAAFFFFFF.toInt())
            setPadding(0, (12 * dp).toInt(), 0, (4 * dp).toInt())
        }
        root.addView(amountLabel)

        val amountInput = EditText(this).apply {
            hint = "1.00"
            setText("1")
            inputType = android.text.InputType.TYPE_CLASS_NUMBER or
                    android.text.InputType.TYPE_NUMBER_FLAG_DECIMAL
            textSize = 18f
            setTextColor(0xFFFFFFFF.toInt())
            setHintTextColor(0x66FFFFFF)
            setBackgroundResource(R.drawable.input_background)
            setPadding((12 * dp).toInt(), (8 * dp).toInt(), (12 * dp).toInt(), (8 * dp).toInt())
        }
        root.addView(amountInput)

        // Ergebnis-Container
        val resultContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, (12 * dp).toInt(), 0, 0)
        }
        root.addView(resultContainer)

        // Ergebniszeilen vorbereiten
        val resultViews = mutableMapOf<String, TextView>()
        val flags = mapOf("EUR" to "🇪🇺", "USD" to "🇺🇸", "TRY" to "🇹🇷", "GBP" to "🇬🇧", "CHF" to "🇨🇭")

        currencies.forEach { cur ->
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(0, (4 * dp).toInt(), 0, (4 * dp).toInt())
            }
            val label = TextView(this).apply {
                text = "${flags[cur]} $cur"
                textSize = 13f
                setTextColor(0xCCFFFFFF.toInt())
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            }
            val value = TextView(this).apply {
                text = "-"
                textSize = 14f
                setTypeface(null, android.graphics.Typeface.BOLD)
                setTextColor(0xFFFFD700.toInt())
                gravity = Gravity.END
            }
            resultViews[cur] = value
            row.addView(label)
            row.addView(value)
            resultContainer.addView(row)
        }

        // Schließen Button
        val closeBtn = Button(this).apply {
            text = "Schließen"
            textSize = 13f
            setTextColor(0xFFFFFFFF.toInt())
            setBackgroundResource(R.drawable.button_background)
            val lp = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            lp.topMargin = (16 * dp).toInt()
            layoutParams = lp
            setOnClickListener { finish() }
        }
        root.addView(closeBtn)

        // Update-Funktion
        fun updateResults() {
            val base = spinner.selectedItem as? String ?: "EUR"
            val amount = amountInput.text.toString().toDoubleOrNull() ?: 1.0
            val baseRate = rates[base] ?: 1.0
            currencies.forEach { cur ->
                val targetRate = rates[cur] ?: 1.0
                val result = amount * (targetRate / baseRate)
                val formatted = when {
                    result >= 1000 -> "%.2f".format(result)
                    result >= 1 -> "%.4f".format(result)
                    else -> "%.6f".format(result)
                }
                resultViews[cur]?.text = formatted
            }
        }

        updateResults()

        spinner.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(p: AdapterView<*>?, v: android.view.View?, pos: Int, id: Long) {
                updateResults()
            }
            override fun onNothingSelected(p: AdapterView<*>?) {}
        }

        amountInput.addTextChangedListener(object : TextWatcher {
            override fun afterTextChanged(s: Editable?) { updateResults() }
            override fun beforeTextChanged(s: CharSequence?, a: Int, b: Int, c: Int) {}
            override fun onTextChanged(s: CharSequence?, a: Int, b: Int, c: Int) {}
        })

        // Tastatur automatisch anzeigen
        amountInput.requestFocus()
        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE)

        return root
    }
}
