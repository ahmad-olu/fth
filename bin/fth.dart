// ignore_for_file: public_member_api_docs, sort_constructors_first
// import 'package:fth/fth.dart' as fth;

// void main(List<String> arguments) {
//   print('Hello world: ${fth.calculate()}!');
// }

import 'dart:collection';
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:path/path.dart' as path;

final projectDir = 'example'; // Change to 'test' or other directory
final entryFile = 'main.dart';
const outputDir = "html";

void main(List<String> arguments) async {
  try {
    final analyzer = WidgetAnalyzer();
    await analyzer.analyze(projectDir, entryFile);
    for (final widget in analyzer.widgets) {}
  } catch (e, st) {
    if (e is PathNotFoundException) {
      print('File `main.dart` not found');
      return;
    }
    print('❌ Error: $e');
    print(st);
  }
}

class WidgetAnalyzer {
  final List<String> _unVisitedStack = [];
  final Set<String> _visited = {};
  final List<WidgetInfo> widgets = [];

  Future<void> analyze(String dir, String entry) async {
    final start = path.normalize(path.join(dir, entry));
    final absStart = path.normalize(path.absolute(start));
    if (!File(absStart).existsSync()) {
      stderr.writeln('Entry not found: $absStart');
      return;
    }

    _unVisitedStack.add(absStart);

    while (_unVisitedStack.isNotEmpty) {
      final abs = _unVisitedStack.removeLast();

      if (!_visited.add(abs)) continue;

      final file = File(abs);
      if (!file.existsSync()) continue;

      final content = await file.readAsString();
      final parseResult = parseString(
        content: content,
        path: abs,
        featureSet: FeatureSet.latestLanguageVersion(),
        throwIfDiagnostics: false,
      );

      final unit = parseResult.unit;

      for (final directive in unit.directives.whereType<ImportDirective>()) {
        final uri = directive.uri.stringValue;
        if (uri == null) continue;

        if (uri.startsWith('dart:') || uri.startsWith('package:')) continue;

        final resolved = path.normalize(path.join(path.dirname(abs), uri));

        if (!_visited.contains(resolved)) {
          _unVisitedStack.add(resolved);
        }
      }

      // find widget classes and their build() return expressions
      for (final decl in unit.declarations) {
        if (decl is ClassDeclaration) {
          final extendsClause = decl.extendsClause;
          if (extendsClause == null) continue;

          final superName = extendsClause.superclass.name.lexeme.trim();

          if (superName != 'Widget' &&
              superName != 'StatelessWidget' &&
              superName != 'StatefulWidget' &&
              !superName.endsWith('Widget')) {
            continue;
          }

          final className = decl.name.lexeme;

          for (final member in decl.members) {
            if (member is MethodDeclaration && member.name.lexeme == 'build') {
              final returnExprs = <Expression>[];
              final body = member.body;

              if (body is BlockFunctionBody) {
                for (final stmt in body.block.statements) {
                  if (stmt is ReturnStatement) {
                    final res = _parseWidgetFromExpression(stmt.expression);
                    for (final a in res) {
                      // if (a.properties is ColumnProp) {
                      //   final p = a.properties as ColumnProp;
                      //   print(".. : ${a.name} = ${a.children.length} \n");
                      //   continue;
                      // }
                      for (final b in a.children) {
                        print(".. : ${a.name} = ${b.name}\n");
                      }
                      // print(".. : ${a.name} = ${a.children.length}\n");
                    }
                    print("\n");
                  }
                }
              } else if (body is ExpressionFunctionBody) {
                // => expr;
                returnExprs.add(body.expression);
              }
            }
          }
        }
      }
    }
  }

  List<WidgetInfo> _parseWidgetFromExpression(Expression? expr) {
    if (expr == null) return [];

    final results = <WidgetInfo>[];
    final uncheckedExpressions = <Expression>[expr];

    while (uncheckedExpressions.isNotEmpty) {
      final newExpr = uncheckedExpressions.removeLast();

      if (expr is ParenthesizedExpression) {
        print("=> _parseWidgetFromExpression: ParenthesizedExpression: $expr");
        uncheckedExpressions.add(newExpr);
        continue;
      }

      if (newExpr is InstanceCreationExpression ||
          newExpr is MethodInvocation) {
        final name = newExpr is InstanceCreationExpression
            ? newExpr.constructorName.type.name.lexeme
            : (newExpr as MethodInvocation).methodName.name;

        final props = <String, dynamic>{};
        final out = <WidgetInfo>[];
        final completeProp = <Properties>[];
        completeProp.clear();
        final args = newExpr is InstanceCreationExpression
            ? newExpr.argumentList.arguments
            : (newExpr as MethodInvocation).argumentList.arguments;

        for (final arg in args) {
          if (arg is NamedExpression) {
            final label = arg.name.label.name;

            if (label == 'body') {
              uncheckedExpressions.add(arg.expression);
            } else if (label == 'child') {
              uncheckedExpressions.add(arg.expression);
            } else if (label == 'children' && arg.expression is ListLiteral) {
              final list = arg.expression as ListLiteral;
              for (final elem in list.elements) {
                if (elem is Expression) {
                  //FIXME: the arrangement of widget as a list in children wont work because well they are in a list
                  final val = _parseWidgetFromExpression(elem);
                  if (val.isNotEmpty) out.addAll(val);
                }
              }
            } else {
              props[label] = _exprToValue(arg.expression);
            }
          } else if (arg is SimpleStringLiteral) {
            if (name.toLowerCase() == "text") {
              props["data"] = arg.value;
            }
          } else {
            print(":::: ${arg.runtimeType} => ${arg.unParenthesized}");
          }

          final widgetProps = extractWidgetProperties(name, props);
          completeProp.add(widgetProps);

          // print("${value.properties.runtimeType}");
        }
        final value = WidgetInfo().copyWith(
          name: name,
          properties: completeProp,
          children: out,
        );

        results.add(value);
        // add here
      }
    }

    return results;
  }

  Properties extractWidgetProperties(
    String widgetName,
    Map<String, dynamic> props,
  ) {
    final name = widgetName.toLowerCase();
    switch (name) {
      case 'scaffold':
        return ScaffoldProp.fromJson(props);
      case 'text':
        return TextProp.fromJson(props);

      case 'container':
        return ContainerProp.fromJson(props);

      case 'sizedbox':
        return SizedBoxProp.fromJson(props);

      case 'center':
        return CenterProp.fromJson(props);

      case 'align':
        return AlignProp.fromJson(props);
      case 'padding':
        return PaddingProp.fromJson(props);
      case 'margin':
        return MarginProp.fromJson(props);
      case 'column':
        return ColumnProp.fromJson(props);

      // add more widget types here...
      default:
        throw UnimplementedError("widget: $widgetName; props:$props");
    }
  }

  dynamic _exprToValue(Expression expr) {
    if (expr is SimpleStringLiteral) return expr.value;
    if (expr is IntegerLiteral) return expr.value;
    if (expr is DoubleLiteral) return expr.value;
    if (expr is BooleanLiteral) return expr.value;
    if (expr is NullLiteral) return null;
    if (expr is PrefixedIdentifier) {
      // e.g. Colors.red or Alignment.center
      final prefix = expr.prefix.name.toLowerCase();
      final identifier = expr.identifier.name;
      if (prefix == 'colors') return identifier;
      if (prefix == 'alignment') return identifier;
      if (prefix == 'mainaxisalignment') return identifier;
      if (prefix == 'crossaxisalignment') return identifier;
      if (prefix == 'mainaxissize') return identifier;
      throw UnimplementedError(
        "_exprToValue: PrefixedIdentifier: ${expr.toSource()}",
      );
    }

    if (expr is Identifier) {
      // e.g. EdgeInsets.all
      return expr.name;
    }

    if (expr is InstanceCreationExpression) {
      // handle nested constructors like EdgeInsets.all(8)
      final name = expr.constructorName.type.name.lexeme;
      final props = <String, dynamic>{};

      for (final arg in expr.argumentList.arguments) {
        if (arg is NamedExpression) {
          props[arg.name.label.name] = _exprToValue(arg.expression);
        } else if (arg is SimpleStringLiteral) {
          // Positional string argument
          if (!props.containsKey('_positional')) {
            props['_positional'] = [];
          }
          (props['_positional'] as List).add(arg.value);
        } else {
          // Other positional arguments
          if (!props.containsKey('_positional')) {
            props['_positional'] = [];
          }
          (props['_positional'] as List).add(_exprToValue(arg));
        }
      }

      return {'_type': name, ...props};
    }

    if (expr is MethodInvocation) {
      final method = expr.methodName.name;
      final props = <String, dynamic>{};

      for (final arg in expr.argumentList.arguments) {
        if (arg is NamedExpression) {
          props[arg.name.label.name] = _exprToValue(arg.expression);
        } else {
          if (!props.containsKey('_positional')) {
            props['_positional'] = [];
          }
          (props['_positional'] as List).add(_exprToValue(arg));
        }
      }

      // If it's a property access like EdgeInsets.all(8)
      if (expr.target != null) {
        final target = expr.target;
        if (target is SimpleIdentifier) {
          return {'_type': target.name, '_method': method, ...props};
        }
      }

      return {'_method': method, ...props};
    }

    throw UnimplementedError("_exprToValue:${expr.runtimeType} => ${expr}");
  }
}

class WidgetInfo {
  final String? name;
  // final WidgetType widgetType;
  final List<Properties> properties;
  final WidgetInfo? child;
  final List<WidgetInfo> children;
  // final String filePath;
  // final int offset;

  WidgetInfo({
    this.name,
    // required this.widgetType,
    this.properties = const [],
    this.child,
    this.children = const [],
    // required this.filePath,
    // required this.offset,
  });

  @override
  String toString() => "`$name => $properties => $child`";

  WidgetInfo copyWith({
    String? name,
    List<Properties>? properties,
    WidgetInfo? child,
    List<WidgetInfo>? children,
  }) {
    return WidgetInfo(
      name: name ?? this.name,
      properties: properties ?? this.properties,
      child: child ?? this.child,
      children: children ?? this.children,
    );
  }
}

enum WidgetType { text, container, padding, custom, unImplemented }

WidgetType _widgetTypeFromName(String name) {
  switch (name.toLowerCase()) {
    case 'text':
      return WidgetType.text;
    case 'container':
      return WidgetType.container;
    case 'padding':
      return WidgetType.padding;
    default:
      return WidgetType.unImplemented;
  }
}

abstract class Properties {}

class ScaffoldProp extends Properties {
  ScaffoldProp();

  factory ScaffoldProp.fromJson(Map<String, dynamic> json) {
    return ScaffoldProp();
  }
}

//todo: work with defaults later
class ColumnProp extends Properties {
  ColumnProp({
    this.mainAxisAlignment = "start",
    this.crossAxisAlignment = "center",
    this.mainAxisSize = "max",
    this.spacing = 0.0,
  });

  final String? mainAxisAlignment;
  final String? crossAxisAlignment;
  final String? mainAxisSize;
  final double? spacing;

  factory ColumnProp.fromJson(Map<String, dynamic> json) {
    //print("====> ${json}");
    return ColumnProp(
      mainAxisAlignment: json['mainAxisAlignment'] as String?,
      crossAxisAlignment: json['crossAxisAlignment'] as String?,
      mainAxisSize: json['mainAxisSize'] as String?,
      spacing: json['spacing'] as double?,
    );
  }
}

class TextProp extends Properties {
  final String data;
  final String? color;

  TextProp({required this.data, this.color});

  factory TextProp.fromJson(Map<String, dynamic> json) {
    return TextProp(
      // data: (json['_positional']?[0] ?? '') as String,
      data: json['data'] as String,
      color: json['selectionColor'] as String?,
    );
  }
}

class ContainerProp extends Properties {
  final String? color;
  final PaddingProp? padding;
  final MarginProp? margin;

  ContainerProp({this.color, this.padding, this.margin});

  factory ContainerProp.fromJson(Map<String, dynamic> json) {
    // print("${json['margin']}<<======");

    return ContainerProp(
      color: json['color'] as String?,
      padding: PaddingProp.fromJson(
        json['padding'] as Map<String, dynamic>? ?? {},
      ),
      margin: MarginProp.fromJson(
        json['margin'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

class SizedBoxProp extends Properties {
  final double? height;
  final double? width;

  SizedBoxProp({this.height, this.width});

  factory SizedBoxProp.fromJson(Map<String, dynamic> json) {
    return SizedBoxProp(
      height: json['height'] as double?,
      width: json['width'] as double?,
    );
  }
}

class CenterProp extends Properties {
  final double? widthFactor;
  final double? heightFactor;

  CenterProp({this.heightFactor, this.widthFactor});

  factory CenterProp.fromJson(Map<String, dynamic> json) {
    return CenterProp(
      heightFactor: json['heightFactor'] as double?,
      widthFactor: json['widthFactor'] as double?,
    );
  }
}

class AlignProp extends Properties {
  final double? widthFactor;
  final double? heightFactor;
  final String? alignment;

  AlignProp({this.heightFactor, this.widthFactor, this.alignment});

  factory AlignProp.fromJson(Map<String, dynamic> json) {
    return AlignProp(
      heightFactor: json['height'] as double?,
      widthFactor: json['width'] as double?,
      alignment: json['alignment'] as String?,
    );
  }
}

class PaddingProp extends Properties {
  final String? pType; // e.g. "EdgeInsets"
  final String? method; // e.g. "all", "symmetric"
  final double? value; // e.g. 12.0 (for EdgeInsets.all)
  final double? vertical;
  final double? horizontal;
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;

  PaddingProp({
    this.pType,
    this.method,
    this.value,
    this.vertical,
    this.horizontal,
    this.top,
    this.bottom,
    this.left,
    this.right,
  });

  factory PaddingProp.fromJson(Map<String, dynamic> json) {
    final method = json['_method'] as String?;
    final positional = (json['_positional'] as List?) ?? [];

    // Default values
    double? value;
    double? vertical;
    double? horizontal;
    double? top;
    double? bottom;
    double? left;
    double? right;

    switch (method) {
      case 'all':
        // e.g. EdgeInsets.all(12)
        value = _toDoubleSafe(positional.isNotEmpty ? positional.first : null);
        break;

      case 'symmetric':
        // e.g. EdgeInsets.symmetric(vertical: 12)
        vertical = _toDoubleSafe(json['vertical']);
        horizontal = _toDoubleSafe(json['horizontal']);
        break;

      case 'only':
        // e.g. EdgeInsets.only(top: 8, left: 16)
        top = _toDoubleSafe(json['top']);
        bottom = _toDoubleSafe(json['bottom']);
        left = _toDoubleSafe(json['left']);
        right = _toDoubleSafe(json['right']);
        break;

      default:
        // fallback if unknown method
        value = _toDoubleSafe(positional.isNotEmpty ? positional.first : null);
        break;
    }

    return PaddingProp(
      pType: json['_type'] as String?,
      method: method,
      value: value,
      vertical: vertical,
      horizontal: horizontal,
      top: top,
      bottom: bottom,
      left: left,
      right: right,
    );
  }

  static double? _toDoubleSafe(dynamic v) {
    if (v is int) return v.toDouble();
    if (v is double) return v;
    if (v is String) return double.tryParse(v);
    return null;
  }

  @override
  String toString() {
    return 'PaddingProp($pType.$method, value: $value, vertical: $vertical, horizontal: $horizontal, '
        'top: $top, bottom: $bottom, left: $left, right: $right)';
  }
}

class MarginProp extends Properties {
  final String? pType; // e.g. "EdgeInsets"
  final String? method; // e.g. "all", "symmetric"
  final double? value; // e.g. 12.0 (for EdgeInsets.all)
  final double? vertical;
  final double? horizontal;
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;

  MarginProp({
    this.pType,
    this.method,
    this.value,
    this.vertical,
    this.horizontal,
    this.top,
    this.bottom,
    this.left,
    this.right,
  });

  factory MarginProp.fromJson(Map<String, dynamic> json) {
    final method = json['_method'] as String?;
    final positional = (json['_positional'] as List?) ?? [];

    // Default values
    double? value;
    double? vertical;
    double? horizontal;
    double? top;
    double? bottom;
    double? left;
    double? right;

    switch (method) {
      case 'all':
        // e.g. EdgeInsets.all(12)
        value = _toDoubleSafe(positional.isNotEmpty ? positional.first : null);
        break;

      case 'symmetric':
        // e.g. EdgeInsets.symmetric(vertical: 12)
        vertical = _toDoubleSafe(json['vertical']);
        horizontal = _toDoubleSafe(json['horizontal']);
        break;

      case 'only':
        // e.g. EdgeInsets.only(top: 8, left: 16)
        top = _toDoubleSafe(json['top']);
        bottom = _toDoubleSafe(json['bottom']);
        left = _toDoubleSafe(json['left']);
        right = _toDoubleSafe(json['right']);
        break;

      default:
        // fallback if unknown method
        value = _toDoubleSafe(positional.isNotEmpty ? positional.first : null);
        break;
    }

    return MarginProp(
      pType: json['_type'] as String?,
      method: method,
      value: value,
      vertical: vertical,
      horizontal: horizontal,
      top: top,
      bottom: bottom,
      left: left,
      right: right,
    );
  }

  static double? _toDoubleSafe(dynamic v) {
    if (v is int) return v.toDouble();
    if (v is double) return v;
    if (v is String) return double.tryParse(v);
    return null;
  }

  @override
  String toString() {
    return 'PaddingProp($pType.$method, value: $value, vertical: $vertical, horizontal: $horizontal, '
        'top: $top, bottom: $bottom, left: $left, right: $right)';
  }
}
