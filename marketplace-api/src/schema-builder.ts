/**
 * Type-safe schema builder for Widget marketplace
 * 
 * This module provides a fluent API for building widget schemas
 * that are guaranteed to be compatible with the Flutter app.
 */

// Element types matching Flutter's ElementType enum
export type ElementType =
  | 'text'
  | 'icon'
  | 'row'
  | 'column'
  | 'spacer'
  | 'gauge'
  | 'chart'
  | 'image'
  | 'container'
  | 'conditional';

// Gauge types
export type GaugeType = 'linear' | 'radial' | 'semicircle';

// Chart types
export type ChartType = 'sparkline' | 'bar' | 'line';

// Font weights
export type FontWeight = 'normal' | 'w400' | 'w500' | 'w600' | 'bold' | 'w700';

// Main axis alignment
export type MainAxisAlignment =
  | 'start'
  | 'end'
  | 'center'
  | 'spaceBetween'
  | 'spaceAround'
  | 'spaceEvenly';

// Cross axis alignment
export type CrossAxisAlignment = 'start' | 'end' | 'center' | 'stretch';

// Widget sizes
export type WidgetSize = 'small' | 'medium' | 'large';

/**
 * Style configuration for elements
 */
export interface StyleConfig {
  textColor?: string;
  backgroundColor?: string;
  fontSize?: number;
  fontWeight?: FontWeight;
  iconSize?: number;
  padding?: number;
  spacing?: number;
  borderRadius?: number;
  width?: number;
  height?: number;
  mainAxisAlignment?: MainAxisAlignment;
  crossAxisAlignment?: CrossAxisAlignment;
  alignment?: 'center' | 'start' | 'end';
}

/**
 * Binding configuration for data-bound elements
 */
export interface BindingConfig {
  path: string;
  format?: string;
  defaultValue?: string;
  transform?: 'round' | 'floor' | 'ceil' | 'uppercase' | 'lowercase';
}

/**
 * Element schema that matches Flutter's ElementSchema
 */
export interface ElementSchemaOutput {
  type: ElementType;
  style?: Record<string, unknown>;
  binding?: BindingConfig;
  children?: ElementSchemaOutput[];
  // Text
  text?: string;
  // Icon
  iconName?: string;
  iconSize?: number;
  // Gauge
  gaugeType?: GaugeType;
  gaugeMin?: number;
  gaugeMax?: number;
  gaugeColor?: string;
  gaugeBackgroundColor?: string;
  // Chart
  chartType?: ChartType;
  chartBindingPath?: string;
  chartMaxPoints?: number;
}

/**
 * Widget schema output
 */
export interface WidgetSchemaOutput {
  name: string;
  description?: string;
  version: string;
  tags?: string[];
  size: WidgetSize;
  root: ElementSchemaOutput;
}

/**
 * Builder class for creating elements
 */
export class ElementBuilder {
  private schema: ElementSchemaOutput;

  constructor(type: ElementType) {
    this.schema = { type };
  }

  style(config: StyleConfig): this {
    this.schema.style = { ...config };
    return this;
  }

  binding(config: BindingConfig): this {
    this.schema.binding = config;
    return this;
  }

  text(value: string): this {
    this.schema.text = value;
    return this;
  }

  icon(name: string, size?: number): this {
    this.schema.iconName = name;
    if (size !== undefined) {
      this.schema.iconSize = size;
    }
    return this;
  }

  gauge(config: {
    type: GaugeType;
    min: number;
    max: number;
    color?: string;
    backgroundColor?: string;
  }): this {
    this.schema.gaugeType = config.type;
    this.schema.gaugeMin = config.min;
    this.schema.gaugeMax = config.max;
    if (config.color) this.schema.gaugeColor = config.color;
    if (config.backgroundColor) this.schema.gaugeBackgroundColor = config.backgroundColor;
    return this;
  }

  chart(config: {
    type: ChartType;
    bindingPath: string;
    maxPoints?: number;
  }): this {
    this.schema.chartType = config.type;
    this.schema.chartBindingPath = config.bindingPath;
    if (config.maxPoints) this.schema.chartMaxPoints = config.maxPoints;
    return this;
  }

  children(elements: ElementBuilder[]): this {
    this.schema.children = elements.map(e => e.build());
    return this;
  }

  build(): ElementSchemaOutput {
    return this.schema;
  }
}

/**
 * Builder class for creating widget schemas
 */
export class WidgetSchemaBuilder {
  private schema: WidgetSchemaOutput;

  constructor(name: string) {
    this.schema = {
      name,
      version: '1.0.0',
      size: 'medium',
      root: { type: 'column' },
    };
  }

  description(value: string): this {
    this.schema.description = value;
    return this;
  }

  version(value: string): this {
    this.schema.version = value;
    return this;
  }

  tags(values: string[]): this {
    this.schema.tags = values;
    return this;
  }

  size(value: WidgetSize): this {
    this.schema.size = value;
    return this;
  }

  root(element: ElementBuilder): this {
    this.schema.root = element.build();
    return this;
  }

  build(): WidgetSchemaOutput {
    return this.schema;
  }
}

// Factory functions for creating elements
export const el = {
  text: (value?: string) => {
    const builder = new ElementBuilder('text');
    if (value) builder.text(value);
    return builder;
  },

  icon: (name: string, size?: number) => {
    return new ElementBuilder('icon').icon(name, size);
  },

  row: (...children: ElementBuilder[]) => {
    return new ElementBuilder('row').children(children);
  },

  column: (...children: ElementBuilder[]) => {
    return new ElementBuilder('column').children(children);
  },

  spacer: (width?: number, height?: number) => {
    const builder = new ElementBuilder('spacer');
    const style: StyleConfig = {};
    if (width !== undefined) style.width = width;
    if (height !== undefined) style.height = height;
    if (Object.keys(style).length > 0) builder.style(style);
    return builder;
  },

  gauge: (config: {
    type: GaugeType;
    min: number;
    max: number;
    color?: string;
    backgroundColor?: string;
    bindingPath?: string;
  }) => {
    const builder = new ElementBuilder('gauge').gauge(config);
    if (config.bindingPath) {
      builder.binding({ path: config.bindingPath });
    }
    return builder;
  },

  chart: (config: {
    type: ChartType;
    bindingPath: string;
    maxPoints?: number;
  }) => {
    return new ElementBuilder('chart').chart(config);
  },
};

// Factory function for creating widget schemas
export const widget = (name: string) => new WidgetSchemaBuilder(name);

// Example usage:
/*
const batteryWidget = widget('Battery Gauge')
  .description('Shows battery level')
  .version('1.0.0')
  .tags(['battery', 'status'])
  .size('medium')
  .root(
    el.column(
      el.row(
        el.icon('battery_full', 20).style({ textColor: '#4ADE80' }),
        el.spacer(8),
        el.text('Battery').style({ fontSize: 14, fontWeight: 'w600', textColor: '#FFFFFF' }),
      ),
      el.text()
        .binding({ path: 'node.batteryLevel', format: '{value}%', defaultValue: '--' })
        .style({ fontSize: 32, fontWeight: 'bold', textColor: '#FFFFFF' }),
      el.gauge({
        type: 'linear',
        min: 0,
        max: 100,
        color: '#4ADE80',
        bindingPath: 'node.batteryLevel',
      }).style({ height: 6 }),
    ).style({ padding: 12, spacing: 8 })
  )
  .build();
*/
