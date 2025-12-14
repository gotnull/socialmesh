const mqtt = require('mqtt');
const client = mqtt.connect('mqtt://mqtt.meshtastic.org:1883', { username: 'meshdev', password: 'large4cats' });

client.on('connect', () => {
  console.log('Connected, subscribing...');
  client.subscribe('msh/+/2/json/#');
});

const types = {};
let nodeinfos = [];
client.on('message', (topic, msg) => {
  try {
    const json = JSON.parse(msg.toString());
    types[json.type] = (types[json.type] || 0) + 1;
    if (json.type === 'nodeinfo') {
      nodeinfos.push(json);
    }
  } catch { }
});

setTimeout(() => {
  console.log('Message types received:');
  console.log(types);
  console.log('\nNodeinfo messages:', nodeinfos.length);
  if (nodeinfos.length > 0) {
    console.log('\nSample nodeinfo payloads:');
    nodeinfos.slice(0, 3).forEach((ni, i) => {
      console.log(`\n[${i + 1}]:`, JSON.stringify(ni.payload, null, 2));
    });
  }
  client.end();
  process.exit(0);
}, 20000);
