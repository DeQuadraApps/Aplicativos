import 'dart:convert';
import 'package:http/http.dart' as http;

class CnpjService {
  Future<Map<String, dynamic>?> fetchCnpjData(String cnpj) async {
    // Remove qualquer máscara do CNPJ, deixando apenas os números
    final cleanCnpj = cnpj.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanCnpj.length != 14) {
      return null;
    }

    try {
      final url = Uri.parse('https://brasilapi.com.br/api/cnpj/v1/$cleanCnpj');
      final response = await http.get(url, headers: {
        'Accept': 'application/json',
      });

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        // Retorna null se o CNPJ não for encontrado ou houver outro erro
        return null;
      }
    } catch (e) {
      // Retorna null em caso de erro de conexão
      print("Erro ao buscar CNPJ: $e");
      return null;
    }
  }
}