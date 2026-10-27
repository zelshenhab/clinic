import { Router } from 'express';
import { z } from 'zod';
import type { User } from '@supabase/supabase-js';
import type { PatientRepository } from '../patients/repository.js';
import { uuid } from '../admin/validation.js';
import { clinicIdSchema } from '@clinic/shared-contracts';
export interface AuthGateway { user(header?:string):Promise<User>; logout(token:string):Promise<void>; }
export function accountRoutes(auth:AuthGateway,patients:PatientRepository) {
 const router=Router();
 router.use(['/auth','/me'],async(req,res,next)=>{res.locals.user=await auth.user(req.headers.authorization);next();});
 const ok=(res:import('express').Response,data:unknown)=>res.json({success:true,data,message:'Operation completed successfully'});
 router.post('/auth/verify-session',async(_req,res)=>ok(res,{id:res.locals.user.id,phone:res.locals.user.phone}));
 router.get('/auth/me',async(_req,res)=>ok(res,{id:res.locals.user.id,phone:res.locals.user.phone}));
 router.post('/auth/logout',async(req,res)=>{await auth.logout(req.headers.authorization!.slice(7));ok(res,null);});
 router.get('/me/profile',async(_req,res)=>ok(res,await patients.profile(res.locals.user.id)));
 router.patch('/me/profile',async(req,res)=>{
  const input=z.object({full_name:z.string().trim().min(2).max(120),email:z.email().nullable().optional(),language:z.enum(['ru','en']).optional()}).strict().parse(req.body);
  ok(res,await patients.update(res.locals.user.id,input));
 });
 const familyMember=z.object({full_name:z.string().trim().min(2).max(120),relationship:z.enum(['child','spouse','parent','sibling','other']),date_of_birth:z.iso.date().refine(d=>d<=new Date().toISOString().slice(0,10)).nullable().optional()}).strict();
 router.get('/me/family-members',async(_req,res)=>ok(res,await patients.familyMembers(res.locals.user.id)));
 router.post('/me/family-members',async(req,res)=>{res.status(201);ok(res,await patients.addFamilyMember(res.locals.user.id,familyMember.parse(req.body)));});
 router.patch('/me/family-members/:id',async(req,res)=>ok(res,await patients.updateFamilyMember(res.locals.user.id,uuid.parse(req.params.id),familyMember.parse(req.body))));
 router.delete('/me/family-members/:id',async(req,res)=>{await patients.removeFamilyMember(res.locals.user.id,uuid.parse(req.params.id));ok(res,null);});
 router.get('/me/notifications',async(req,res)=>ok(res,await patients.notifications(res.locals.user.id,clinicIdSchema.parse(req.query.clinic_id))));
 router.get('/me/appointments',async(req,res)=>ok(res,await patients.appointments(res.locals.user.id,clinicIdSchema.parse(req.query.clinic_id))));
 return router;
}
