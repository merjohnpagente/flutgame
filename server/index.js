import { startServer } from './server.js';

const port = Number(process.env.PORT) || 8080;
const { wss } = startServer(port);

wss.on('listening', () => {
  console.log(`Dungeon server listening on ws://0.0.0.0:${wss.address().port}`);
});
wss.on('error', (error) => {
  console.error(`Server error: ${error.message}`);
  process.exit(1);
});
