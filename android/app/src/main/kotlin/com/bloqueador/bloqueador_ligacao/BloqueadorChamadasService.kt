package com.bloqueador.bloqueador_ligacao

import android.telecom.Call
import android.telecom.CallScreeningService
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Filtra chamadas recebidas usando prefixos armazenados localmente.
 *
 * Não acessa a internet, contatos, SMS, notificações ou outros apps.
 */
class BloqueadorChamadasService : CallScreeningService() {

    companion object {
        private const val PREFS = "bloqueador_local"
        private const val CHAVE_PREFIXOS = "prefixos"
        private const val CHAVE_HISTORICO = "historico_json"
        private const val LIMITE_HISTORICO = 500
    }

    override fun onScreenCall(callDetails: Call.Details) {
        if (callDetails.callDirection != Call.Details.DIRECTION_INCOMING) {
            return
        }

        val numeroOriginal =
            callDetails.handle?.schemeSpecificPart.orEmpty()

        // Sem número identificável, permite a chamada.
        if (numeroOriginal.isBlank()) {
            responder(callDetails, false)
            return
        }

        val preferencias = getSharedPreferences(PREFS, MODE_PRIVATE)
        val prefixos = preferencias
            .getStringSet(CHAVE_PREFIXOS, emptySet())
            .orEmpty()

        val numero = normalizarNumero(numeroOriginal)

        val correspondencia = prefixos.firstOrNull { prefixo ->
            numero.startsWith(normalizarPrefixo(prefixo)) &&
                normalizarPrefixo(prefixo).isNotEmpty()
        }

        if (correspondencia == null) {
            responder(callDetails, false)
            return
        }

        registrarHistorico(
            numeroOriginal,
            correspondencia
        )

        responder(callDetails, true)
    }

    private fun normalizarPrefixo(prefixo: String): String {
        val digitos = prefixo.filter(Char::isDigit)

        // +55 e 55 são tratados como código internacional brasileiro.
        return when {
            prefixo.trim().startsWith("+") &&
                digitos.startsWith("55") &&
                digitos.length > 2 -> "0" + digitos.substring(2)

            digitos.startsWith("55") &&
                digitos.length > 2 -> "0" + digitos.substring(2)

            else -> digitos
        }
    }

    private fun normalizarNumero(numero: String): String {
        val digitos = numero.filter(Char::isDigit)

        return if (
            numero.trim().startsWith("+") &&
            digitos.startsWith("55") &&
            digitos.length > 2
        ) {
            "0" + digitos.substring(2)
        } else {
            digitos
        }
    }

    private fun responder(
        detalhes: Call.Details,
        bloquear: Boolean
    ) {
        val resposta = CallResponse.Builder()
            .setDisallowCall(bloquear)
            .setRejectCall(bloquear)
            .setSkipCallLog(false)
            .setSkipNotification(false)
            .build()

        respondToCall(detalhes, resposta)
    }

    private fun registrarHistorico(
        numero: String,
        prefixo: String
    ) {
        val preferencias = getSharedPreferences(PREFS, MODE_PRIVATE)
        val historicoAtual = preferencias.getString(
            CHAVE_HISTORICO,
            "[]"
        ) ?: "[]"

        val arrayAnterior = JSONArray(historicoAtual)
        val novoArray = JSONArray()

        // Preserva os registros mais recentes, respeitando o limite.
        val inicio = (arrayAnterior.length() - LIMITE_HISTORICO + 1)
            .coerceAtLeast(0)

        for (i in inicio until arrayAnterior.length()) {
            novoArray.put(arrayAnterior.getJSONObject(i))
        }

        val data = SimpleDateFormat(
            "dd/MM/yyyy HH:mm:ss",
            Locale.getDefault()
        ).format(Date())

        novoArray.put(
            JSONObject()
                .put("numero", numero)
                .put("prefixo", prefixo)
                .put("data", data)
        )

        // commit() grava os dados antes de terminar esta operação.
        preferencias.edit()
            .putString(CHAVE_HISTORICO, novoArray.toString())
            .commit()
    }
}
