import {
  ElementBuilder,
  WidgetSchemaBuilder,
  el,
  widget,
  type ElementSchemaOutput,
  type WidgetSchemaOutput,
} from './schema-builder';

describe('ElementBuilder', () => {
  describe('basic element creation', () => {
    it('should create a text element with type', () => {
      const element = new ElementBuilder('text').build();
      expect(element.type).toBe('text');
    });

    it('should create an icon element with type', () => {
      const element = new ElementBuilder('icon').build();
      expect(element.type).toBe('icon');
    });

    it('should create a row element with type', () => {
      const element = new ElementBuilder('row').build();
      expect(element.type).toBe('row');
    });

    it('should create a column element with type', () => {
      const element = new ElementBuilder('column').build();
      expect(element.type).toBe('column');
    });
  });

  describe('text()', () => {
    it('should set text property', () => {
      const element = new ElementBuilder('text').text('Hello World').build();
      expect(element.text).toBe('Hello World');
    });
  });

  describe('icon()', () => {
    it('should set iconName property', () => {
      const element = new ElementBuilder('icon').icon('battery_full').build();
      expect(element.iconName).toBe('battery_full');
    });

    it('should set iconName and iconSize properties', () => {
      const element = new ElementBuilder('icon').icon('battery_full', 24).build();
      expect(element.iconName).toBe('battery_full');
      expect(element.iconSize).toBe(24);
    });

    it('should not set iconSize when undefined', () => {
      const element = new ElementBuilder('icon').icon('battery_full').build();
      expect(element.iconSize).toBeUndefined();
    });
  });

  describe('style()', () => {
    it('should set style properties', () => {
      const element = new ElementBuilder('text')
        .style({
          textColor: '#FFFFFF',
          fontSize: 16,
          fontWeight: 'bold',
        })
        .build();

      expect(element.style).toEqual({
        textColor: '#FFFFFF',
        fontSize: 16,
        fontWeight: 'bold',
      });
    });

    it('should handle layout style properties', () => {
      const element = new ElementBuilder('row')
        .style({
          mainAxisAlignment: 'spaceBetween',
          crossAxisAlignment: 'center',
          padding: 12,
          spacing: 8,
        })
        .build();

      expect(element.style).toEqual({
        mainAxisAlignment: 'spaceBetween',
        crossAxisAlignment: 'center',
        padding: 12,
        spacing: 8,
      });
    });
  });

  describe('binding()', () => {
    it('should set binding with path only', () => {
      const element = new ElementBuilder('text')
        .binding({ path: 'node.batteryLevel' })
        .build();

      expect(element.binding).toEqual({ path: 'node.batteryLevel' });
    });

    it('should set binding with all properties', () => {
      const element = new ElementBuilder('text')
        .binding({
          path: 'node.batteryLevel',
          format: '{value}%',
          defaultValue: '--',
          transform: 'round',
        })
        .build();

      expect(element.binding).toEqual({
        path: 'node.batteryLevel',
        format: '{value}%',
        defaultValue: '--',
        transform: 'round',
      });
    });
  });

  describe('gauge()', () => {
    it('should set gauge properties', () => {
      const element = new ElementBuilder('gauge')
        .gauge({
          type: 'linear',
          min: 0,
          max: 100,
        })
        .build();

      expect(element.gaugeType).toBe('linear');
      expect(element.gaugeMin).toBe(0);
      expect(element.gaugeMax).toBe(100);
    });

    it('should set gauge with color and background', () => {
      const element = new ElementBuilder('gauge')
        .gauge({
          type: 'radial',
          min: 0,
          max: 100,
          color: '#4ADE80',
          backgroundColor: '#333333',
        })
        .build();

      expect(element.gaugeType).toBe('radial');
      expect(element.gaugeColor).toBe('#4ADE80');
      expect(element.gaugeBackgroundColor).toBe('#333333');
    });
  });

  describe('chart()', () => {
    it('should set chart properties', () => {
      const element = new ElementBuilder('chart')
        .chart({
          type: 'sparkline',
          bindingPath: 'node.history',
        })
        .build();

      expect(element.chartType).toBe('sparkline');
      expect(element.chartBindingPath).toBe('node.history');
    });

    it('should set chart with maxPoints', () => {
      const element = new ElementBuilder('chart')
        .chart({
          type: 'line',
          bindingPath: 'node.history',
          maxPoints: 50,
        })
        .build();

      expect(element.chartMaxPoints).toBe(50);
    });
  });

  describe('children()', () => {
    it('should set children elements', () => {
      const child1 = new ElementBuilder('text').text('Child 1');
      const child2 = new ElementBuilder('text').text('Child 2');

      const element = new ElementBuilder('column')
        .children([child1, child2])
        .build();

      expect(element.children).toHaveLength(2);
      expect(element.children?.[0].text).toBe('Child 1');
      expect(element.children?.[1].text).toBe('Child 2');
    });

    it('should handle nested children', () => {
      const innerRow = new ElementBuilder('row').children([
        new ElementBuilder('text').text('Nested'),
      ]);

      const element = new ElementBuilder('column')
        .children([innerRow])
        .build();

      expect(element.children?.[0].type).toBe('row');
      expect(element.children?.[0].children?.[0].text).toBe('Nested');
    });
  });

  describe('method chaining', () => {
    it('should support fluent API', () => {
      const element = new ElementBuilder('text')
        .text('Battery')
        .style({ fontSize: 14, textColor: '#FFFFFF' })
        .build();

      expect(element.type).toBe('text');
      expect(element.text).toBe('Battery');
      expect(element.style).toEqual({ fontSize: 14, textColor: '#FFFFFF' });
    });
  });
});

describe('WidgetSchemaBuilder', () => {
  describe('constructor', () => {
    it('should create widget with name and defaults', () => {
      const schema = new WidgetSchemaBuilder('Test Widget').build();

      expect(schema.name).toBe('Test Widget');
      expect(schema.version).toBe('1.0.0');
      expect(schema.size).toBe('medium');
      expect(schema.root.type).toBe('column');
    });
  });

  describe('description()', () => {
    it('should set description', () => {
      const schema = new WidgetSchemaBuilder('Test')
        .description('A test widget')
        .build();

      expect(schema.description).toBe('A test widget');
    });
  });

  describe('version()', () => {
    it('should set version', () => {
      const schema = new WidgetSchemaBuilder('Test')
        .version('2.0.0')
        .build();

      expect(schema.version).toBe('2.0.0');
    });
  });

  describe('tags()', () => {
    it('should set tags', () => {
      const schema = new WidgetSchemaBuilder('Test')
        .tags(['battery', 'status', 'gauge'])
        .build();

      expect(schema.tags).toEqual(['battery', 'status', 'gauge']);
    });
  });

  describe('size()', () => {
    it('should set size to small', () => {
      const schema = new WidgetSchemaBuilder('Test')
        .size('small')
        .build();

      expect(schema.size).toBe('small');
    });

    it('should set size to large', () => {
      const schema = new WidgetSchemaBuilder('Test')
        .size('large')
        .build();

      expect(schema.size).toBe('large');
    });
  });

  describe('root()', () => {
    it('should set root element', () => {
      const rootElement = new ElementBuilder('row').children([
        new ElementBuilder('text').text('Hello'),
      ]);

      const schema = new WidgetSchemaBuilder('Test')
        .root(rootElement)
        .build();

      expect(schema.root.type).toBe('row');
      expect(schema.root.children?.[0].text).toBe('Hello');
    });
  });
});

describe('el factory functions', () => {
  describe('el.text()', () => {
    it('should create text element without value', () => {
      const element = el.text().build();
      expect(element.type).toBe('text');
      expect(element.text).toBeUndefined();
    });

    it('should create text element with value', () => {
      const element = el.text('Hello').build();
      expect(element.type).toBe('text');
      expect(element.text).toBe('Hello');
    });
  });

  describe('el.icon()', () => {
    it('should create icon element', () => {
      const element = el.icon('battery_full').build();
      expect(element.type).toBe('icon');
      expect(element.iconName).toBe('battery_full');
    });

    it('should create icon element with size', () => {
      const element = el.icon('battery_full', 24).build();
      expect(element.iconName).toBe('battery_full');
      expect(element.iconSize).toBe(24);
    });
  });

  describe('el.row()', () => {
    it('should create row with children', () => {
      const element = el.row(
        el.text('Item 1'),
        el.text('Item 2'),
      ).build();

      expect(element.type).toBe('row');
      expect(element.children).toHaveLength(2);
    });

    it('should create empty row', () => {
      const element = el.row().build();
      expect(element.type).toBe('row');
      expect(element.children).toEqual([]);
    });
  });

  describe('el.column()', () => {
    it('should create column with children', () => {
      const element = el.column(
        el.text('Line 1'),
        el.text('Line 2'),
      ).build();

      expect(element.type).toBe('column');
      expect(element.children).toHaveLength(2);
    });
  });

  describe('el.spacer()', () => {
    it('should create spacer without dimensions', () => {
      const element = el.spacer().build();
      expect(element.type).toBe('spacer');
      expect(element.style).toBeUndefined();
    });

    it('should create spacer with width', () => {
      const element = el.spacer(8).build();
      expect(element.type).toBe('spacer');
      expect(element.style).toEqual({ width: 8 });
    });

    it('should create spacer with width and height', () => {
      const element = el.spacer(8, 16).build();
      expect(element.style).toEqual({ width: 8, height: 16 });
    });
  });

  describe('el.gauge()', () => {
    it('should create gauge element', () => {
      const element = el.gauge({
        type: 'linear',
        min: 0,
        max: 100,
        color: '#4ADE80',
      }).build();

      expect(element.type).toBe('gauge');
      expect(element.gaugeType).toBe('linear');
      expect(element.gaugeMin).toBe(0);
      expect(element.gaugeMax).toBe(100);
      expect(element.gaugeColor).toBe('#4ADE80');
    });

    it('should create gauge with binding', () => {
      const element = el.gauge({
        type: 'radial',
        min: 0,
        max: 100,
        bindingPath: 'node.batteryLevel',
      }).build();

      expect(element.binding).toEqual({ path: 'node.batteryLevel' });
    });
  });

  describe('el.chart()', () => {
    it('should create chart element', () => {
      const element = el.chart({
        type: 'sparkline',
        bindingPath: 'node.history',
        maxPoints: 30,
      }).build();

      expect(element.type).toBe('chart');
      expect(element.chartType).toBe('sparkline');
      expect(element.chartBindingPath).toBe('node.history');
      expect(element.chartMaxPoints).toBe(30);
    });
  });
});

describe('widget() factory function', () => {
  it('should create a WidgetSchemaBuilder', () => {
    const builder = widget('My Widget');
    expect(builder).toBeInstanceOf(WidgetSchemaBuilder);
  });

  it('should support fluent building', () => {
    const schema = widget('My Widget')
      .description('A custom widget')
      .version('1.0.0')
      .tags(['custom'])
      .size('medium')
      .build();

    expect(schema.name).toBe('My Widget');
    expect(schema.description).toBe('A custom widget');
  });
});

describe('Integration: Complete widget schema', () => {
  it('should build a battery widget matching Flutter format', () => {
    const schema = widget('Battery Gauge')
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
        ).style({ padding: 12, spacing: 8 }),
      )
      .build();

    // Verify top-level properties
    expect(schema.name).toBe('Battery Gauge');
    expect(schema.description).toBe('Shows battery level');
    expect(schema.version).toBe('1.0.0');
    expect(schema.tags).toEqual(['battery', 'status']);
    expect(schema.size).toBe('medium');

    // Verify root element
    expect(schema.root.type).toBe('column');
    expect(schema.root.style).toEqual({ padding: 12, spacing: 8 });
    expect(schema.root.children).toHaveLength(3);

    // Verify header row
    const headerRow = schema.root.children![0];
    expect(headerRow.type).toBe('row');
    expect(headerRow.children).toHaveLength(3);
    expect(headerRow.children![0].iconName).toBe('battery_full');
    expect(headerRow.children![0].style).toEqual({ textColor: '#4ADE80' });

    // Verify binding text
    const bindingText = schema.root.children![1];
    expect(bindingText.binding).toEqual({
      path: 'node.batteryLevel',
      format: '{value}%',
      defaultValue: '--',
    });

    // Verify gauge
    const gauge = schema.root.children![2];
    expect(gauge.gaugeType).toBe('linear');
    expect(gauge.binding).toEqual({ path: 'node.batteryLevel' });
  });

  it('should produce JSON compatible with Flutter WidgetSchema.fromJson', () => {
    const schema = widget('Test')
      .root(
        el.column(
          el.text('Hello').style({ textColor: '#FFFFFF' }),
        ).style({ padding: 8 }),
      )
      .build();

    const json = JSON.stringify(schema);
    const parsed = JSON.parse(json) as WidgetSchemaOutput;

    // Verify it can be serialized and deserialized
    expect(parsed.name).toBe('Test');
    expect(parsed.root.type).toBe('column');
    expect(parsed.root.children![0].text).toBe('Hello');

    // Verify structure matches Flutter expectations
    expect(parsed.root.children![0]).toHaveProperty('text');
    expect(parsed.root.children![0]).toHaveProperty('style');
    expect(parsed.root.children![0]).not.toHaveProperty('properties'); // Not using old format
  });
});
