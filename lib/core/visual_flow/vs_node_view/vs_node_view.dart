// Vendored from vs_node_view v2.1.1
// Original: https://github.com/Cunibon/vs_node_view
// License: BSD-3-Clause (see LICENSE in this directory)
//
// Modifications for Socialmesh:
// - Import paths rewritten from package:vs_node_view/ to relative
// - Sci-fi theming (glass morphism, glow wires, accent colors)
// - Mobile UX (28dp touch targets, tap-to-connect, drag thresholds)
// - Selection area rewritten for mobile (no Alt-key dependency)
// - Line painter extended with glow/shadow pass
// - Custom interface types for automation flow signals

// Interfaces
export 'data/standard_interfaces/vs_bool_interface.dart'
    show VSBoolInputData, VSBoolOutputData;
export 'data/standard_interfaces/vs_double_interface.dart'
    show VSDoubleInputData, VSDoubleOutputData;
export 'data/standard_interfaces/vs_dynamic_interface.dart'
    show VSDynamicInputData, VSDynamicOutputData;
export 'data/standard_interfaces/vs_int_interface.dart'
    show VSIntInputData, VSIntOutputData;
export 'data/standard_interfaces/vs_num_interface.dart'
    show VSNumInputData, VSNumOutputData;
export 'data/standard_interfaces/vs_string_interface.dart'
    show VSStringInputData, VSStringOutputData;
export 'data/vs_history_manager.dart' show VSHistoryManager;

// Data
export 'data/vs_interface.dart' show VSInputData, VSOutputData, VSInterfaceData;
export 'data/vs_node_data.dart' show VSNodeData;
export 'data/vs_node_data_provider.dart' show VSNodeDataProvider;
export 'data/vs_node_manager.dart' show VSNodeManager;
export 'data/vs_subgroup.dart' show VSSubgroup;
export 'data/evaluation_error.dart' show EvaluationError;

// Special Nodes
export 'special_nodes/vs_list_node.dart' show VSListNode;
export 'special_nodes/vs_output_node.dart' show VSOutputNode;
export 'special_nodes/vs_widget_node.dart' show VSWidgetNode;

// Widgets
export 'widgets/interactive_vs_node_view.dart' show InteractiveVSNodeView;
export 'widgets/vs_node.dart' show VSNode;
export 'widgets/vs_node_view.dart' show VSNodeView;
export 'widgets/inherited_node_data_provider.dart'
    show InheritedNodeDataProvider;

// Common
export 'common.dart' show VSNodeDataBuilder;
