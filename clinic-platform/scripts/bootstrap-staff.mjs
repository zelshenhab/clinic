// Run once with a server-only environment, after creating the initial Auth identity.
import {createClient} from '@supabase/supabase-js';
const id=process.argv[2],url=process.env.SUPABASE_URL,key=process.env.SUPABASE_SERVICE_ROLE_KEY;
if(!id||!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)||!url||!key)throw Error('Usage: node --env-file=.env scripts/bootstrap-staff.mjs <existing-auth-user-uuid>');
const db=createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}});
const {data,error}=await db.auth.admin.getUserById(id);if(error||!data.user)throw Error('Auth identity could not be verified');
const result=await db.rpc('bootstrap_super_admin',{p_user:id});if(result.error)throw Error('Bootstrap rejected; verify migrations and whether an administrator already exists');
console.log('Initial super administrator assigned and audited.');
