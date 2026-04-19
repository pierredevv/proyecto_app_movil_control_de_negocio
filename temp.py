import os, re

files = [
    r'd:\Documents\Proyectos\Proyectos Antigravity\Proyectos Flutter\proyecto_app_movil_control_de_negocio\lib\screens\customers\customer_form_screen.dart',
    r'd:\Documents\Proyectos\Proyectos Antigravity\Proyectos Flutter\proyecto_app_movil_control_de_negocio\lib\screens\suppliers\supplier_form_screen.dart',
    r'd:\Documents\Proyectos\Proyectos Antigravity\Proyectos Flutter\proyecto_app_movil_control_de_negocio\lib\screens\expenses\expense_form_screen.dart'
]

for f in files:
    with open(f, 'r', encoding='utf-8') as file:
        content = file.read()
        
    content = content.replace('_GlassTextFieldGroup(', 'GlassTextFieldGroup(')
    
    # regex to eliminate the class
    content = re.sub(r'class _GlassTextFieldGroup extends StatefulWidget.*?class _GlassTextFieldGroupState extends State<_GlassTextFieldGroup>.*?}(?=\s*class|\s*$)', '', content, flags=re.DOTALL)
    
    if "import '../../widgets/common/glass_text_field_group.dart';" not in content:
        content = content.replace("import '../../services/contact_helper.dart';", "import '../../services/contact_helper.dart';\nimport '../../widgets/common/glass_text_field_group.dart';")
        content = content.replace("import '../../providers/expense_provider.dart';", "import '../../providers/expense_provider.dart';\nimport '../../widgets/common/glass_text_field_group.dart';")
        
    with open(f, 'w', encoding='utf-8') as file:
        file.write(content)
