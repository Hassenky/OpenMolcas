************************************************************************
* This file is part of OpenMolcas.                                     *
*                                                                      *
* OpenMolcas is free software; you can redistribute it and/or modify   *
* it under the terms of the GNU Lesser General Public License, v. 2.1. *
* OpenMolcas is distributed in the hope that it will be useful, but it *
* is provided "as is" and without any express or implied warranties.   *
* For more details see the full text of the license in the file        *
* LICENSE or in <http://www.gnu.org/licenses/>.                        *
*                                                                      *
* Copyright (C) 1994, Martin Schuetz                                   *
*               2017, Roland Lindh                                     *
************************************************************************
      SubRoutine SOrUpV(NoAllo,V,HDiag,lvec,W,Mode)
************************************************************************
*     for Ref., see T.H. Fischer and J. Almloef, JPC 96, 9768 (1992)   *
*               DOI: 10.1021/j100203a036                               *
*                                                                      *
*     purpose: Second Order Updated vector V using BFGS and            *
*              diagonal Hessian of Orbital Rotations                   *
*     input  : NoAllo     -> this routine tries to allocate memory     *
*                to construct linked lists, so you have to tell, how   *
*                much you want to keep for your own purpose...         *
*              for all procedure parameters, iad prefix means the      *
*              address of the var on Work Array                        *
*              V          -> input vector                              *
*              HDiag      -> initial diagonal Hessian                  *
*              lvec       -> lengths of vectors delta, grad, HDiag & V *
*              Mode       -> update mode, see below                    *
*     The routine expects, that grad(n) and delta(n-1) are already     *
*     stored on the appropriate linked lists LLGrad & LLDelt.          *
*     output:  W          -> H(n)V with H(n) SOrUp (inverse) Hessian   *
*                            after n-1 updates                         *
*                            mem has to be allocated from caller side  *
*                                                                      *
*     called from: WfCtl_SCF, iErrV                                    *
*                                                                      *
*     calls to: uses SubRoutines and Functions from Module lnklst.f    *
*               -linked list implementation to store series of vectors *
*                                                                      *
*----------------------------------------------------------------------*
*                                                                      *
*     written by:                                                      *
*     M. Schuetz                                                       *
*     University of Lund, Sweden, 1994                                 *
*                                                                      *
*     Adapted to work both for d=-H(-1)g and g = -Hd                   *
*     depending on the value of MODE                                   *
*     Mode='DISP':  d=-H(-1)g    BFGS update for the inverse Hessian   *
*     Mode='GRAD':  g=-Hd        DFP  update for the Hessian           *
*     2017, Roland Lindh, Harvard, Cambridge                           *
*                                                                      *
*----------------------------------------------------------------------*
*                                                                      *
*     history: none                                                    *
*                                                                      *
************************************************************************
      Implicit Real*8 (a-h,o-z)
#include "file.fh"
#include "llists.fh"
#include "real.fh"
#include "mxdm.fh"
#include "infscf.fh"
*     only tentatively this inc file
#include "infso.fh"
#include "WrkSpc.fh"
#include "stdalloc.fh"
*
*     declaration subroutine parameters
      Integer NoAllo,lvec
      Real*8 W(lVec), HDiag(lVec), V(lvec)
      Character*4 Mode
*
*     declaration local variables
      Character*4 Mode_Old
      Save Mode_Old
      Integer ipdel,ipdgd,ipynm1
      Integer i,it,inode,leny
      Logical updy
      Real*8 S(6),T(4)
*     declarations of functions
      Integer LstPtr
      real*8 ddot_
      Real*8 Cpu1,Tim1,Tim2,Tim3
      Real*8, Dimension(:), Allocatable:: SOGrd, SODel, SOScr
      Logical Inverse_H
*
      Call Timing(Cpu1,Tim1,Tim2,Tim3)
      nD = iUHF + 1
      Thr=1.0D-9
*
*     This section will control the mode
*
      If (MODE.eq.'DISP') Then
*
*        Mode for computation d = -H(-1)g
*
         Inverse_H=.True.
         Lu1=LuGrd
         LL1=LLGrad
         Lu2=LuDel
         LL2=LLDelt
         Lu3=LudGd
         LL3=LLDgrd
         Lu4=LuX
         LL4=LLX
*
      Else If (MODE.eq.'GRAD') Then
*
*        Mode for computation g = -Hd
*
         Inverse_H=.False.
         Lu1=LuX
         LL1=LLX
         Lu2=LudGd
         LL2=LLdGrd
         Lu3=LuDel
         LL3=LLDelt
         Lu4=LuGrd
         LL4=LLGrad
*
      Else
*
*        The statments before the abend is there just to make sure
*        that the compiler doesn't warn for possible use of non-
*        initialized variables.
*
         Inverse_H=.False.
         Lu1=LuX
         LL1=LLX
         Lu2=LudGd
         LL2=LLdGrd
         Lu3=LuDel
         LL3=LLDelt
         Lu4=LuGrd
         LL4=LLGrad
*
         Write (6,*) 'SOrUpV: Illegal mode'
         Call Abend()
      End If
*
      If (iterso.gt.1.AND.Mode.ne.Mode_Old) Then
         Write (6,*) 'SOrUpV: Illegal mode switch'
         Call Abend()
      End If
*
*     Steps denoted as in the reference paper!
*
*     (1): initialize w=HDiag*v
*
      Do i=1,lvec
         If (Inverse_H) Then
            If (HDiag(i).ne.0.0D0) Then
               W(i)=V(i)/HDiag(i)
            Else
               W(i)=V(i)*1.0D2
            End If
         Else
            W(i)=HDiag(i)*V(i)
         End If
      End Do
*define _DEBUG_
#ifdef _DEBUG_
      Call RecPrt('SORUPV: v        ',' ',V,1,lvec)
      Call RecPrt('SORUPV: HDiag    ',' ',HDiag,1,lvec)
      If (MODE.eq.'SORUPV: DISP') Then
         Call RecPrt('SORUPV: W=HDiag(-1)*v',' ',W,1,lvec)
      Else
         Call RecPrt('SORUPV: W=HDiag*v',' ',W,1,lvec)
      End If
#endif

*define _DIAGONAL_ONLY_
#ifdef _DIAGONAL_ONLY_
      If (.True.) Then
         Write (6,*) ' SorUpV: Only diagonal approximation'
#else
      If (iterso.eq.1) Then
#endif
*       (2): no further work required this time
        Call Timing(Cpu2,Tim1,Tim2,Tim3)
        TimFld( 7) = TimFld( 7) + (Cpu2 - Cpu1)
        Mode_Old=Mode
        Return
      End If
*
*     need three vectors of length lvec as scratch space
*
      Call mma_allocate(SOGrd,lvec,Label='SOGrd')
      Call mma_allocate(SODel,lvec,Label='SODel')
      Call FZero(SODel,lvec)
      Call mma_allocate(SOScr,lvec,Label='SOScr')
*
      Call GetNod(iter-1,LL3,inode)
      If (inode.eq.0) GoTo 555
      Call iVPtr(Lu3,SODel,lvec,inode)
*define _DEBUG_SORUPV_
#ifdef _DEBUG_SORUPV_
#ifdef _DEBUG_
      Write (6,*) 'n-1=',iter-1
      If (MODE.eq.'GRAD') Then
         Call RecPrt('SORUPV: dX(n-1)',' ',SODel,1,lVec)
*        Call NrmClc(SODel,lVec,'SORUPV','dX(n-1)')
      Else If (MODE.eq.'DISP') Then
         Call RecPrt('SORUPV: dg(n-1)',' ',SODel,1,lVec)
*        Call NrmClc(SODel,lVec,'SORUPV','dg(n-1)')
      Else
         Write (6,*) 'SOrUpV: Illegal mode'
         Call Abend()
      End If
#endif
#endif
*
*     (3b): initialize y(n-1)=HDiag*Dgrd(n-1) ...
*
      Do i=1,lvec
        If (Inverse_H) Then
           If (HDiag(i).ne.0.0D0) Then
              SOScr(i)=SODel(i)/HDiag(i)
           Else
              SOScr(i)=1.0D2*SODel(i)
           End If
        Else
           SOScr(i)=HDiag(i)*SODel(i)
        End If
      End Do
#ifdef _DEBUG_
      Call RecPrt('Init y(n-1)',' ',SOScr,1,lVec)
#endif
#ifdef _DEBUG_SORUPV_
#ifdef _DEBUG_
      Call RecPrt('SORUV: HdX(n-1)',' ',SOScr,1,lVec)
#endif
#endif
*
*     and store it on appropriate linked list
*
      leny=LLLen(LLy)
      Call PutVec(SOScr,lvec,Luy,iter-1,NoAllo,'OVWR',LLy)
      If (leny.eq.LLLen(LLy)) Then
*       already there, so we don't have to recalculate later
c       updy=.FALSE.
        updy=.TRUE.
      Else
*       new listhead generated in ipy, we have to update
        updy=.TRUE.
      End If
*
*     (4): now loop over 1..n-2 iterations.
*
      Do it=iter-iterso+1,iter-2
*
*       fetch delta(i), Dgrd(i) and y(i) from corresponding LLists
*
        Call GetNod(it,LL2,inode)
        If (inode.eq.0) GoTo 555
        Call iVPtr(Lu2,SODel,lvec,inode)
*
        Call GetNod(it,LL3,inode)
        If (inode.eq.0) GoTo 555
        Call iVPtr(Lu3,SOGrd,lvec,inode)
*
        Call GetNod(it,LLy,inode)
        If (inode.eq.0) GoTo 555
        Call iVPtr(Luy,SOScr,lvec,inode)
*
*       calculate S_k and T_k dot products.
*
        S(1)=DDOT_(lvec,SODel,1,SOGrd,1)
        If (Abs(S(1)).lt.Thr) Then
           S(1)=Zero
        Else
           S(1)=One/S(1)
        End If
        S(2)=DDOT_(lvec,SOGrd,1,SOScr,1)
        If (S(2).lt.Thr) Then
           S(2)=Zero
        Else
           S(2)=One/S(2)
        End If
        S(3)=DDOT_(lvec,SODel,1,V,1)
        S(4)=DDOT_(lvec,SOScr,1,V,1)
*
*       here we have to reload Dgrd(n-1) from llist, but this
*       for sure is a memory hit, since it was put there last
*
        ipdgd=LstPtr(Lu3,iter-1,LL3)
*
        S(5)=DDOT_(lvec,SODel,1,Work(ipdgd),1)
        S(6)=DDOT_(lvec,SOScr,1,Work(ipdgd),1)
#ifdef _DEBUG_
        Write (6,*) 'it=',it
        Write (6,*) '(S(i),i=1,6)=',(S(i),i=1,6)
#endif
*
        T(2)=S(1)*S(3)
        T(4)=S(1)*S(5)
        T(1)=S(1)*S(4)
        T(3)=S(1)*S(6)
        If (S(2).eq.0.0D0) Then
           S(1)=One
        Else
           S(1)=One+S(1)/S(2)
        End If
        T(1)=S(1)*T(2)-T(1)
        T(3)=S(1)*T(4)-T(3)
*
*       Compute w and y_{n-1}
*
#ifdef _DEBUG_
        Write (6,*) '(T(i),i=1,4)=',(T(i),i=1,4)
#endif
        call daxpy_(lvec, T(1),SODel,1,W,1)
        call daxpy_(lvec,-T(2),SOScr,1,W,1)
        If (updy) Then
*
*         here we have to reload y(n-1) from llist, but this
*         for sure is a memory hit, since it was put there last
*         -> we operate directly on the memory cells of the LList,
*         where y(n-1) resides.
*
          ipynm1=LstPtr(Luy,iter-1,LLy)
          call daxpy_(lvec, T(3),SODel,1,Work(ipynm1),1)
          call daxpy_(lvec,-T(4),SOScr,1,Work(ipynm1),1)
        End If
*
      End Do
*
*     (5): reload y(n-1), delta(n-1) & DGrd(n-1) from linked list.
*     these all are memory hits, of course
*
      ipynm1=LstPtr(Luy,iter-1,LLy)
      ipdel =LstPtr(Lu2,iter-1,LL2)
      ipdgd =LstPtr(Lu3,iter-1,LL3)
#ifdef _DEBUG_
      If (MODE.eq.'DISP') Then
         Call RecPrt('y(n-1)',' ',Work(ipynm1),1,lVec)
         Call RecPrt('dX(n-1)',' ',Work(ipdel),1,lVec)
         Call RecPrt('dg(n-1)',' ',Work(ipdgd),1,lVec)
      Else
         Call RecPrt('y(n-1)',' ',Work(ipynm1),1,lVec)
         Call RecPrt('dg(n-1)',' ',Work(ipdel),1,lVec)
         Call RecPrt('dX(n-1)',' ',Work(ipdgd),1,lVec)
      End If
#endif
#ifdef _DEBUG_SORUPV_
#ifdef _DEBUG_
      If (MODE.eq.'DISP') Then
         Call NrmClc(Work(ipdel),lVec,'SORUPV','dX(n-1)')
         Call NrmClc(Work(ipdgd),lVec,'SORUPV','dg(n-1)')
      Else
         Call NrmClc(Work(ipdgd),lVec,'SORUPV','dX(n-1)')
         Call NrmClc(Work(ipdel),lVec,'SORUPV','dg(n-1)')
      End If
#endif
#endif
*
*     calculate diverse dot products...
*
      S(1)=DDOT_(lvec,Work(ipdel),1,Work(ipdgd),1)
      If (Abs(S(1)).lt.Thr) Then
         S(1)=0.0D0
      Else
         S(1)=One/S(1)
      End If
      S(2)=DDOT_(lvec,Work(ipdgd),1,Work(ipynm1),1)
      If (S(2).lt.Thr) Then
         S(2)=0.0D0
      Else
         S(2)=One/S(2)
      End If
      S(3)=DDOT_(lvec,Work(ipdel),1,V,1)
      S(4)=DDOT_(lvec,Work(ipynm1),1,V,1)
#ifdef _DEBUG_SORUPV_
#ifdef _DEBUG_
      alpha=S(1)
      beta=One/S(2)
      epsilon=(1.0D0+alpha*beta)*alpha
      Write (6,*) 'SORUPV: a,b,e=',alpha,beta,epsilon
      Call RecPrt('SORUPV: HdX(n-1)',' ',Work(ipynm1),1,lVec)
#endif
#endif
#ifdef _DEBUG_
        Write (6,*) '(S(i),i=1,4)=',(S(i),i=1,4)
#endif
      T(2)=S(1)*S(3)
      T(1)=S(1)*S(4)
      If (S(2).eq.0.0D0) Then
         S(1)=One
      Else
         S(1)=One+S(1)/S(2)
      End If
      T(1)=S(1)*T(2)-T(1)
*
*     update the vector w
*
#ifdef _DEBUG_
      Write (6,*) '(T(i),i=1,2)=',(T(i),i=1,2)
#endif
      call daxpy_(lvec,T(1),Work(ipdel),1,W,1)
      call daxpy_(lvec,-T(2),Work(ipynm1),1,W,1)
#ifdef _DEBUG_
      Call RecPrt('The final W array',' ',W,1,lVec)
#endif
*
*     so, we've made it, let's clean up workbench
*
      Call mma_deallocate(SOGrd)
      Call mma_deallocate(SODel)
      Call mma_deallocate(SOScr)
*
      Call Timing(Cpu2,Tim1,Tim2,Tim3)
      TimFld( 7) = TimFld( 7) + (Cpu2 - Cpu1)
      Return
*
*-----Error handling
*
*     Hmmm, no entry found in LList, that's strange
 555  Write (6,*) 'SOrUpV: no entry found in LList'
      Call QTrace
      Call Abend()
      End
