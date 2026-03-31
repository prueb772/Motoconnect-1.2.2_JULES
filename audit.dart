import 'dart:io';
import 'dart:convert';

void main() {
  final baseDir = Directory('lib/presentation');
  final modules = ['auth', 'community', 'events', 'grupos', 'home', 'navigation', 'profile', 'routes', 'talleres'];
  final subdirs = ['views', 'blocs', 'widgets'];

  final report = <String, dynamic>{};

  for (final mod in modules) {
    var modData = {'files': {'views': [], 'blocs': [], 'widgets': []}, 'violations': []};
    
    for (final subdir in subdirs) {
      final dir = Directory('${baseDir.path}/$subdir/$mod');
      if (dir.existsSync()) {
        final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
        
        for (final file in files) {
          final relPath = file.path.replaceAll('\\', '/').replaceAll('lib/presentation/', '');
          (modData['files'] as Map)[subdir].add(relPath);
          
          final lines = file.readAsLinesSync();
          final isView = subdir == 'views';
          final isBloc = subdir == 'blocs';
          
          for (var i = 0; i < lines.length; i++) {
            final lineNum = i + 1;
            final line = lines[i];
            
            // Clean Architecture
            if (line.contains('supabase_flutter.dart')) {
              (modData['violations'] as List).add({'crit': 'Clean Architecture', 'state': '❌', 'file': relPath, 'line': lineNum, 'desc': 'Importa supabase_flutter directamente'});
            }
            
            if (isView && line.contains('Impl(')) {
              (modData['violations'] as List).add({'crit': 'Clean Architecture', 'state': '❌', 'file': relPath, 'line': lineNum, 'desc': 'Instancia repositorio directo'});
            }
            
            if (isBloc && line.contains('Supabase.instance')) {
              (modData['violations'] as List).add({'crit': 'Clean Architecture', 'state': '❌', 'file': relPath, 'line': lineNum, 'desc': 'Acceso a Supabase en BLoC sin repo'});
            }
            if (isBloc && line.contains('Impl') && line.contains('import')) {
              (modData['violations'] as List).add({'crit': 'Clean Architecture', 'state': '❌', 'file': relPath, 'line': lineNum, 'desc': 'BLoC depende de implementacion concreta (import)'});
            }
            if (isBloc && line.contains('Impl(')) {
              (modData['violations'] as List).add({'crit': 'Clean Architecture', 'state': '❌', 'file': relPath, 'line': lineNum, 'desc': 'BLoC instancia implementacion concreta'});
            }
            
            // MVVM
            if (isView && line.contains('setState(')) {
              (modData['violations'] as List).add({'crit': 'MVVM', 'state': '⚠️', 'file': relPath, 'line': lineNum, 'desc': 'Uso de setState (posible logica de UI o negocio)'});
            }
            
            // Modelos Tipados
            if (line.contains('Map<String, dynamic>') && !line.contains('Map<String, dynamic> json')) {
              if (relPath.contains('state') || relPath.contains('event') || isView) {
                (modData['violations'] as List).add({'crit': 'Modelos tipados', 'state': '❌', 'file': relPath, 'line': lineNum, 'desc': 'Uso de Map<String, dynamic> local o en estado'});
              }
            }
          }
        }
      }
    }
    report[mod] = modData;
  }
  
  File('audit_results.json').writeAsStringSync(jsonEncode(report));
  print('Audit finished');
}
