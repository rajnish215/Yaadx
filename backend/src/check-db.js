import {makePool} from './config.js';
const pool=makePool();
try {
 const c=await pool.connect();
 const tls=c.connection.stream.encrypted===true && c.connection.stream.authorized===true;
 console.log(JSON.stringify({connected:true,tlsCertificateVerified:tls}));
 c.release();if(!tls)throw new Error('TLS verification failed');
 const tables=await pool.query("SELECT count(*)::int AS count FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog','information_schema')");
 console.log(JSON.stringify({existingTableCount:tables.rows[0].count}));
} catch {console.error('Database connection failed (credentials omitted)');process.exitCode=1;} finally {await pool.end();}
