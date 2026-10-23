
package com.bloqueador.bloqueador_ligacao

import android.app.Activity
import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.telecom.TelecomManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {

    companion object {
        private const val CANAL = "bloqueador/telefonia"
        private const val PEDIDO_AUTORIZACAO = 7314
        private const val PREFS = "bloqueador_local"
        private const val CHAVE_PREFIXOS = "prefixos"
        private const val CHAVE_HISTORICO = "historico_json"
        private const val LIMITE_HISTORICO = 500
    }

    private var resultadoAutorizacao: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CANAL
        ).setMethodCallHandler { chamada, resultado ->
            when (chamada.method) {
                "sincronizarPrefixos" -> {
                    val lista = chamada.argument<List<String>>("prefixos")
                    if (lista == null) {
                        resultado.error("DADOS_INVALIDOS", "Lista ausente.", null)
                    } else {
                        val prefixos = lista
                            .map { it.filter(Char::isDigit) }
                            .filter { it.length in 2..15 }
                            .toSet()

                        getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                            .edit()
                            .putStringSet(CHAVE_PREFIXOS, prefixos)
                            .commit()

                        resultado.success(null)
                    }
                }

                "verificarAutorizacao" -> {
                    resultado.success(temAutorizacao())
                }

                "solicitarAutorizacao" -> {
                    solicitarAutorizacao(resultado)
                }

                "obterHistorico" -> {
                    resultado.success(obterHistorico())
                }

                else -> resultado.notImplemented()
            }
        }
    }

    private fun temAutorizacao(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val gerenciador = getSystemService(RoleManager::class.java)
            return gerenciador.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)
        }

        val telecom = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
        return telecom.defaultDialerPackage == packageName
    }

    private fun solicitarAutorizacao(resultado: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            resultado.error(
                "VERSAO_NAO_SUPORTADA",
                "Esta implementação requer Android 10 ou superior.",
                null
            )
            return
        }

        val gerenciador = getSystemService(RoleManager::class.java)

        if (!gerenciador.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING)) {
            resultado.error(
                "FUNCAO_INDISPONIVEL",
                "O Android não disponibilizou a função de filtragem.",
                null
            )
            return
        }

        if (gerenciador.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)) {
            resultado.success(null)
            return
        }

        if (resultadoAutorizacao != null) {
            resultado.error(
                "PEDIDO_EM_ANDAMENTO",
                "Já existe um pedido de autorização aberto.",
                null
            )
            return
        }

        resultadoAutorizacao = resultado

        try {
            val intent = gerenciador.createRequestRoleIntent(
                RoleManager.ROLE_CALL_SCREENING
            )
            startActivityForResult(intent, PEDIDO_AUTORIZACAO)
        } catch (e: Exception) {
            resultadoAutorizacao = null
            resultado.error(
                "ERRO_AUTORIZACAO",
                e.message ?: "Não foi possível abrir a autorização.",
                null
            )
        }
    }

    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?
    ) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == PEDIDO_AUTORIZACAO) {
            resultadoAutorizacao?.success(temAutorizacao())
            resultadoAutorizacao = null
        }
    }

    private fun obterHistorico(): List<Map<String, String>> {
        val preferencias = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val json = preferencias.getString(CHAVE_HISTORICO, "[]") ?: "[]"
        val array = JSONArray(json)
        val registros = mutableListOf<Map<String, String>>()

        for (i in 0 until array.length()) {
            val objeto = array.optJSONObject(i) ?: continue

            registros.add(
                mapOf(
                    "numero" to objeto.optString("numero"),
                    "prefixo" to objeto.optString("prefixo"),
                    "data" to objeto.optString("data")
                )
            )
        }

        return registros.reversed()
    }

    // Utilizado pelo serviço para manter o histórico limitado.
    internal fun limiteHistorico(): Int = LIMITE_HISTORICO
}
