import { describe,it,expect,vi } from 'vitest';
import request from 'supertest';
import { createApp } from '../src/app.js';
import { requireClinicRole } from '../src/common/middleware/auth.js';
import type { SupabaseClient } from '@supabase/supabase-js';
const config={NODE_ENV:'test' as const,PORT:3000,CORS_ORIGINS:'http://localhost:5173',SUPABASE_URL:'http://localhost:54321',SUPABASE_ANON_KEY:'test',SUPABASE_SERVICE_ROLE_KEY:'test'};
const repository={list:vi.fn(async()=>[]),get:vi.fn(async()=>({})),settings:vi.fn(async()=>({}))};
describe('API foundation',()=>{
 it('returns the shared response envelope and request ID',async()=>{const r=await request(createApp(config,repository)).get('/api/v1/clinics');expect(r.body).toMatchObject({success:true,data:[]});expect(r.headers['x-request-id']).toBeTruthy();});
 it('rejects invalid clinic identifiers before database access',async()=>{repository.get.mockClear();const r=await request(createApp(config,repository)).get('/api/v1/clinics/clinic_001');expect(r.status).toBe(400);expect(repository.get).not.toHaveBeenCalled();});
 it('does not disclose internal exceptions',async()=>{const r=await request(createApp(config,{...repository,list:async()=>{throw Error('SQL secret');}})).get('/api/v1/clinics');expect(r.status).toBe(500);expect(JSON.stringify(r.body)).not.toContain('SQL secret');});
 it('returns consistent unknown-route errors',async()=>{expect((await request(createApp(config,repository)).get('/missing')).body.error.code).toBe('NOT_FOUND');});
 it('prevents a clinic administrator crossing tenant boundaries',async()=>{
  const db={from:()=>({select:()=>({eq:()=>({eq:async()=>({data:[{role:'CLINIC_ADMIN',clinic_id:'clinic-a'}],error:null})})})})} as unknown as SupabaseClient;
  await expect(requireClinicRole(db,'user','clinic-b',['CLINIC_ADMIN'])).rejects.toMatchObject({status:403});
  await expect(requireClinicRole(db,'user','clinic-a',['CLINIC_ADMIN'])).resolves.toBeUndefined();
  await expect(requireClinicRole(db,'user','clinic-a',['RECEPTIONIST'])).rejects.toMatchObject({status:403});
 });
});
