************************************************************************
* This file is part of OpenMolcas.                                     *
*                                                                      *
* OpenMolcas is free software; you can redistribute it and/or modify   *
* it under the terms of the GNU Lesser General Public License, v. 2.1. *
* OpenMolcas is distributed in the hope that it will be useful, but it *
* is provided "as is" and without any express or implied warranties.   *
* For more details see the full text of the license in the file        *
* LICENSE or in <http://www.gnu.org/licenses/>.                        *
************************************************************************
      Subroutine FndTess(iPrint,ToAng,LcNAtm,ipp_Xs,ipp_Ys,ipp_Zs,
     &                   ipp_R,ipp_N)
      Implicit Real*8(A-H,O-Z)
#include "WrkSpc.fh"
#include "rctfld.fh"
#include "status.fh"
*
*     Definition of solute cavity and computation of vertices,
*     representative points and surfaces of the tesserae by the
*     Gauss-Bonnet Theorem.
*
*     Allocate space for X, Y, Z, Area, ISPHE (index of sphere to which
*     tessera belongs); then allocate space for IntSph (indices of spheres
*     cutting the tessera), NewSph (indices of spheres creating new smoothing
*     spheres), SSph (surface of each sphere exposed to the solvent),
*     Finally, allocate temporary space for NVert (number of vertices for
*     any tessera), Vert (coordinates of vertices), Centr (center of arcs).
*
      Call GetMem('XTs'    ,'Allo','Real',ipp_Xt    ,MxTs)
      Call GetMem('YTs'    ,'Allo','Real',ipp_Yt    ,MxTs)
      Call GetMem('ZTs'    ,'Allo','Real',ipp_Zt    ,MxTs)
      Call GetMem('ATs'    ,'Allo','Real',ipp_At    ,MxTs)
      Call GetMem('Vert'   ,'Allo','Real',ipp_Vert  ,3*MxVert*MxTs)
      Call GetMem('Centr'  ,'Allo','Real',ipp_Centr ,3*MxVert*MxTs)
      Call GetMem('SSph'   ,'Allo','Real',ipp_SSph  ,MxSph)
      Call GetMem('JTR'    ,'Allo','Inte',ipp_JTR   ,3*MxTs)
      Call GetMem('CV'     ,'Allo','Real',ipp_CV    ,3000)
      Call GetMem('ISph'   ,'Allo','Inte',ipp_ISph  ,MxTs)
      Call GetMem('NVert'  ,'Allo','Inte',ipp_NVert ,MxTs)
      Call GetMem('IntSph' ,'Allo','Inte',ipp_IntS  ,MxVert*MxTs)
      Call GetMem('NewSph' ,'Allo','Inte',ipp_NewS  ,2*MxSph)
*
      Omega = RSlPar(2)
      Ret = RSlPar(3)
      Fro = RSlPar(4)
      TsAre = RSlPar(7)
      RSolv = RSlPar(19)
      ITsNum = ISlPar(11)
*
      Call FndTess_(iPrint,ToAng,LcNAtm,MxSph,MxTs,
     &             Work(ipp_Xs),Work(ipp_Ys),Work(ipp_Zs),Work(ipp_R),
     &             Ret,Omega,Fro,RSolv,NSinit,NS,ITsNum,TsAre,nTs,
     &             Work(ipp_Xt),Work(ipp_Yt),Work(ipp_Zt),Work(ipp_At),
     &             iWork(ipp_ISph),iWork(ipp_NVert),Work(ipp_Vert),
     &             Work(ipp_Centr),iWork(ipp_IntS),iWork(ipp_NewS),
     &             Work(ipp_SSph),iWork(ipp_JTR),Work(ipp_CV))
*                                                                      *
************************************************************************
*     Re-allocate with actual dimensioning                             *
      If (RctFld_Status.ne.Active) Then
*
         nPCM_info = 4*NS + NS + 4*nTs + 3*MxVert*nTs + 3*MxVert*nTs
     &             + NS + nTs + nTs + MxVert*nTs + 2*NS + nTs**2
*
         Call GetMem('PCMSph','Allo','Real',ip_Sph,nPCM_info)
         Call FZero(Work(ip_Sph),nPCM_info)
*
         mChunk=0
         Call Init_a_Chunk(ip_Sph,mChunk)
         Call Get_a_Chunk('PCMSph','Real',ip_Sph,4*NS)
         Call Get_a_Chunk('NOrd','Inte',ip_N ,NS)
         Call Get_a_Chunk('PCMTess','Real',ip_Tess,4*nTs)
         Call Get_a_Chunk('Vert','Real',ip_Vert,3*MxVert*nTs)
         Call Get_a_Chunk('Centr','Real',ip_Centr,3*MxVert*nTs)
         Call Get_a_Chunk('SSph','Real',ip_SSph,NS)
         Call Get_a_Chunk('ISph','Inte',ip_ISph,nTs)
         Call Get_a_Chunk('NVert','Inte',ip_NVert,nTs)
         Call Get_a_Chunk('IntSph','Inte',ip_IntS,MxVert*nTs)
         Call Get_a_Chunk('NewSph','Inte',ip_NewS,2*NS)
         Call Get_a_Chunk('DM','Real',ip_DM,nTs**2)
         Call nChunk(mChunk)
         If (mChunk.gt.nPCM_info) Then
            Write (6,*) 'FndTss: mChunk.gt.nPCM_info!'
            Write (6,*) 'mChunk=',mChunk
            Write (6,*) 'nPCM_Info=',nPCM_Info
            Call QTrace()
            Call Abend()
         End If
         nPCM_info=mChunk
*
      End If
*
      call dcopy_(nS,Work(ipp_Xs),1,Work(ip_Sph  ),4)
      call dcopy_(nS,Work(ipp_Ys),1,Work(ip_Sph+1),4)
      call dcopy_(nS,Work(ipp_Zs),1,Work(ip_Sph+2),4)
      call dcopy_(nS,Work(ipp_R), 1,Work(ip_Sph+3),4)
*
      Call ICopy(nS,iWork(ipp_N),1,iWork(ip_N),1)
*
      call dcopy_(nTs,Work(ipp_Xt),1,Work(ip_Tess  ),4)
      call dcopy_(nTs,Work(ipp_Yt),1,Work(ip_Tess+1),4)
      call dcopy_(nTs,Work(ipp_Zt),1,Work(ip_Tess+2),4)
      call dcopy_(nTs,Work(ipp_At),1,Work(ip_Tess+3),4)
*
      call dcopy_(3*MxVert*nTs,Work(ipp_Vert),1,Work(ip_Vert),1)
*
      call dcopy_(3*MxVert*nTs,Work(ipp_Centr),1,Work(ip_Centr),1)
*
      call dcopy_(nS,Work(ipp_SSph),1,Work(ip_SSph),1)
*
      Call ICopy(nTs,iWork(ipp_ISph),1,iWork(ip_ISph),1)
*
      Call ICopy(nTs,iWork(ipp_NVert),1,iWork(ip_NVert),1)
*
      Call ICopy(MxVert*nTs,iWork(ipp_IntS),1,iWork(ip_IntS),1)
*
      Call ICopy(2*NS,iWork(ipp_NewS),1,iWork(ip_NewS),1)
*                                                                      *
************************************************************************
*                                                                      *
*     Deallocate temporary memory
*
      Call GetMem('NewSph' ,'Free','Inte',ipp_NewS  ,2*MxSph)
      Call GetMem('IntSph' ,'Free','Inte',ipp_IntS  ,MxVert*MxTs)
      Call GetMem('NVert'  ,'Free','Inte',ipp_NVert ,MxTs)
      Call GetMem('ISph'   ,'Free','Inte',ipp_ISph  ,MxTs)
      Call GetMem('CV'     ,'Free','Real',ipp_CV    ,3000)
      Call GetMem('JTR'    ,'Free','Inte',ipp_JTR   ,3*MxTs)
      Call GetMem('SSph'   ,'Free','Real',ipp_SSph  ,MxSph)
      Call GetMem('Centr'  ,'Free','Real',ipp_Centr ,3*MxVert*MxTs)
      Call GetMem('Vert'   ,'Free','Real',ipp_Vert  ,3*MxVert*MxTs)
      Call GetMem('ATs'    ,'Free','Real',ipp_At    ,MxTs)
      Call GetMem('ZTs'    ,'Free','Real',ipp_Zt    ,MxTs)
      Call GetMem('YTs'    ,'Free','Real',ipp_Yt    ,MxTs)
      Call GetMem('XTs'    ,'Free','Real',ipp_Xt    ,MxTs)
*                                                                      *
************************************************************************
*                                                                      *
      Return
      End
      Subroutine FndTess_(IPrint,ToAng,NAT,MxSph,MxTs,XE,YE,ZE,RE,
     &                   RET,Omega,FRO,RSolv,NEsfP,NEsf,ITsNum,TSAre,
     &                   NTS,XCTs,YCTs,ZCTs,AS,ISphe,Nvert,Vert,
     &                   Centr,IntSph,NewSph,SSfe,JTR,CV)

      Implicit Real*8(A-H,O-Z)
      Parameter (MxVert=20)
C
C     Definition of solute cavity and computation of vertices,
C     representative points and surfaces of the tesserae by the
C     Gauss-Bonnet Theorem.
C
      Dimension XCTs(*),YCTs(*),ZCTs(*),AS(*)
      Dimension ISphe(*)
      Dimension XE(*),YE(*),ZE(*),RE(*)
      Dimension SSFE(*),IntSph(MxVert,*),NVert(*)
      Dimension NewSph(2,*)
      Dimension Vert(3,MxVert,*),Centr(3,MxVert,*)
      Dimension JTR(3,*),CV(3,*)
      Dimension PP(3),PTS(3,MxVert),CCC(3,MxVert)
      Save Zero,First
      DATA ZERO,FIRST/0.0D0,0.0174533D0/
C
C PEDRA works with Angstroms
      DO 2000 ISFE = 1, NESFP
        XE(ISFE) = XE(ISFE) * ToAng
        YE(ISFE) = YE(ISFE) * ToAng
        ZE(ISFE) = ZE(ISFE) * ToAng
 2000 continue
      NESF = NESFP
      IF(IPRINT.EQ.2) WRITE(6,800)
C
C                   creation of new spheres
C
      DO 2010 N = 1, NESF
      NEWSPH(1,N) = 0
      NEWSPH(2,N) = 0
 2010 continue
      ITYPC = 0
      OMEGA=OMEGA*FIRST
      SENOM=Sin(OMEGA)
      COSOM2=(cos(OMEGA))**2
      RTDD=RET+RSOLV
      RTDD2=RTDD*RTDD
      NET=NESF
      NN=2
      NE=NESF
      NEV=NESF
      GO TO 100
  110 NN=NE+1
      NE=NET
      IF(NE.GT.MxSph)THEN
      Write(6,1111)
1111  format(' Cavity: too many spheres; increase Omega')
      Call Abend()
      ENDIF
  100 DO 120 I=NN,NE
      NES=I-1
      DO 130 J=1,NES
      RIJ2=(XE(I)-XE(J))**2+
     $     (YE(I)-YE(J))**2+
     $     (ZE(I)-ZE(J))**2
      RIJ=sqrt(RIJ2)
      RJD=RE(J)+RSOLV
      TEST1=RE(I)+RJD+RSOLV
      IF(RIJ.GE.TEST1) GO TO 130
      REG=MAX(RE(I),RE(J))
      REP=MIN(RE(I),RE(J))
      REG2=REG*REG
      REP2=REP*REP
      TEST2=REP*SENOM+sqrt(REG2-REP2*COSOM2)
      IF(RIJ.LE.TEST2) GO TO 130
      REGD2=(REG+RSOLV)*(REG+RSOLV)
      TEST3=(REGD2+REG2-RTDD2)/REG
      IF(RIJ.GE.TEST3) GO TO 130
      DO 140 K=1,NEV
      IF(K.EQ.J .OR. K.EQ.I) GO TO 140
      RJK2=(XE(J)-XE(K))**2+
     $     (YE(J)-YE(K))**2+
     $     (ZE(J)-ZE(K))**2
      IF(RJK2.GE.RIJ2) GO TO 140
      RIK2=(XE(I)-XE(K))**2+
     $     (YE(I)-YE(K))**2+
     $     (ZE(I)-ZE(K))**2
      IF(RIK2.GE.RIJ2) GO TO 140
       RJK=sqrt(RJK2)
       RIK=sqrt(RIK2)
       SP=(RIJ+RJK+RIK)/2.0D0
       HH=4*(SP*(SP-RIJ)*(SP-RIK)*(SP-RJK))/RIJ2
       REO=RE(K)*FRO
      IF(K.GE.NE)REO=0.0002D0
      REO2=REO*REO
      IF(HH.LT.REO2) GO TO 130
  140 CONTINUE
      REPD2=(REP+RSOLV)**2
      TEST8=sqrt(REPD2-RTDD2)+sqrt(REGD2-RTDD2)
      IF(RIJ.LE.TEST8)GO TO 150
      REND2=REGD2+REG2-(REG/RIJ)*(REGD2+RIJ2-REPD2)
      IF(REND2.LE.RTDD2) GO TO 130
      REN=sqrt(REND2)-RSOLV
      FC=REG/(RIJ-REG)
      TEST7=REG-RE(I)
      KG=I
      KP=J
      IF(TEST7.LE.0.000000001D0) GO TO 160
      KG=J
      KP=I
  160 FC1=FC+1.0D0
      XEN=(XE(KG)+FC*XE(KP))/FC1
      YEN=(YE(KG)+FC*YE(KP))/FC1
      ZEN=(ZE(KG)+FC*ZE(KP))/FC1
      ITYPC = 1
      GO TO 170
  150 R2GN=RIJ-REP+REG
      RGN=R2GN/2.0D0
      FC=R2GN/(RIJ+REP-REG)
      FC1=FC+1.0D0
      TEST7=REG-RE(I)
      KG=I
      KP=J
      IF(TEST7.LE.0.000000001D0) GO TO 180
      KG=J
      KP=I
  180 XEN=(XE(KG)+FC*XE(KP))/FC1
      YEN=(YE(KG)+FC*YE(KP))/FC1
      ZEN=(ZE(KG)+FC*ZE(KP))/FC1
      REN=sqrt(REGD2+RGN*(RGN-(REGD2+RIJ2-REPD2)/RIJ))-RSOLV
  170 NET=NET+1
      XE(NET)=XEN
      YE(NET)=YEN
      ZE(NET)=ZEN
      RE(NET)=REN
C
C     Nella matrice NEWSPH(2,NESF) sono memorizzati i numeri delle
C     sfere "generatrici" della nuova sfera NET: se la nuova sfera e'
C     del tipo A o B entrambi i numeri sono positivi, se e' di tipo
C     C il numero della sfera "principale" e' negativo
C     (per la definizione del tipo si veda JCC 11, 1047 (1990))
C
      IF(ITYPC.EQ.0) THEN
        NEWSPH(1,NET) = KG
        NEWSPH(2,NET) = KP
      ELSEIF(ITYPC.EQ.1) THEN
      NEWSPH(1,NET) = - KG
      NEWSPH(2,NET) = KP
      ENDIF
C
  130 CONTINUE
      NEV=NET
  120 CONTINUE
      IF(NET.NE.NE) GO TO 110
      NESF=NET
C
C                    Division of the surface into tesserae
C
      VCav=ZERO
      Scav=ZERO
C
C     Controlla se ciascuna tessera e' scoperta o va tagliata
C
      NN1 = 0
      DO 300 NSFE = 1, NESF
      XEN = XE(NSFE)
      YEN = YE(NSFE)
      ZEN = ZE(NSFE)
      REN = RE(NSFE)
      If(ITsNum.eq.0.and.TsAre.eq.0.d0) then
        IPtype = 2
        IPFlag = 0
        ITsNum = 60
      ElseIf(ITsNum.gt.0.and.TsAre.eq.0.d0) Then
        IPFlag = 0
      ElseIf(TsAre.gt.0.d0) Then
        IPFlag = 1
      EndIf
      Call PolyGen(MxTs,IPtype,IPflag,TsAre,ITsNum,
     +             XEN,YEN,ZEN,REN,ITsEff,CV,JTR)
      DO 310 ITS = 1, ITsEff
      N1 = JTR(1,ITS)
      N2 = JTR(2,ITS)
      N3 = JTR(3,ITS)
      PTS(1,1)=CV(1,N1)
      PTS(2,1)=CV(2,N1)
      PTS(3,1)=CV(3,N1)
      PTS(1,2)=CV(1,N2)
      PTS(2,2)=CV(2,N2)
      PTS(3,2)=CV(3,N2)
      PTS(1,3)=CV(1,N3)
      PTS(2,3)=CV(2,N3)
      PTS(3,3)=CV(3,N3)
      NV=3
      DO 2020 JJ = 1, 3
      PP(JJ) = ZERO
 2020 continue
C
C     Per ciascuna tessera, trova la porzione scoperta e ne
C     calcola l'area con il teorema di Gauss-Bonnet; il punto
C     rappresentativo e' definito come media dei vertici della porzione
C     scoperta di tessera e passato in PP.
C     I vertici di ciascuna tessera sono conservati in
C     VERT(3,MxVert,MxTs), il numero di vertici di ciascuna tessera e'
C     in NVERT(MxTs), e i centri dei cerchi di ciascun lato sono in
C     CENTR(3,MxVert,MxTs). In INTSPH(MxVert,MxTs) sono registrate le
C     sfere a cui appartengono i lati delle tessere.

      CALL TESSERA(iPrint,MxTs,Nesf,NSFE,NV,XE,YE,ZE,RE,IntSph,
     &             PTS,CCC,PP,AREA)
      IF(AREA.EQ.0.D0) GOTO 310
      NN1 = NN1 + 1
      NN = Min(NN1,MxTs)
      XCTS(NN) = PP(1)
      YCTS(NN) = PP(2)
      ZCTS(NN) = PP(3)
      AS(NN) = AREA

      ISPHE(NN) = NSFE
      NVERT(NN) = NV
      DO 2030 IV = 1, NV
        DO 2040 JJ = 1, 3
          VERT(JJ,IV,NN) = PTS(JJ,IV)
          CENTR(JJ,IV,NN) = CCC(JJ,IV)
 2040 continue
 2030 continue
      DO 2050 IV = 1, NV
        INTSPH(IV,NN) = INTSPH(IV,MxTs)
 2050 continue
 310  CONTINUE
 300  CONTINUE
      NTS = NN
C
C     Verifica se due tessere sono troppo vicine
      TEST = 0.02D0
      TEST2 = TEST*TEST
      DO 400 I = 1, NTS-1
      IF(AS(I).EQ.ZERO) GOTO 400
      XI = XCTS(I)
      YI = YCTS(I)
      ZI = ZCTS(I)
      II = I + 1
      DO 410 J = II , NTS
      IF(ISPHE(I).EQ.ISPHE(J)) GOTO 410
      IF(AS(J).EQ.ZERO) GOTO 410
      XJ = XCTS(J)
      YJ = YCTS(J)
      ZJ = ZCTS(J)
      RIJ = (XI-XJ)**2 + (YI-YJ)**2 + (ZI-ZJ)**2
      IF(RIJ.GT.TEST2) GOTO 410
C
C     La routine originaria sostituiva le due tessere troppo vicine con una
C     sola tessera. Nel caso Gauss-Bonnet, anche i vertici delle tessere
C     e i centri degli archi vengono memorizzati ed e' impossibile sostituirli
C     nello stesso modo: percio' l'area della tessera piu' piccola verra'
C     trascurata per evitare problemi nella autopolarizzazione.
      IF(IPRINT.EQ.2) WRITE(6,1000)I,J,TEST2
      IF(AS(I).LT.AS(J)) AS(I) = ZERO
      IF(AS(I).GE.AS(J)) AS(J) = ZERO
 410  CONTINUE
 400  CONTINUE
C
C     E' preferibile eliminare del tutto le tessere che per
C     qualche motivo hanno AREA = 0, ridefinendo tutti gli
C     indici: l'errore numerico cosi' introdotto e' in genere
C     trascurabile e si evitano problemi di convergenza
C
C     Define here the number of tesserae in electrostatic calculations
C     to avoid problems in successive calcn.
      ITS = 0
450   ITS = ITS + 1
      IF (AS(ITS).LT.1.D-10) THEN
        DO 2060 I = ITS, NTS - 1
          AS(I) = AS(I+1)
          XCTS(I) = XCTS(I+1)
          YCTS(I) = YCTS(I+1)
          ZCTS(I) = ZCTS(I+1)
          ISPHE(I) = ISPHE(I+1)
          NVERT(I) = NVERT(I+1)
          DO 2070 IV = 1, MxVert
            INTSPH(IV,I) = INTSPH(IV,I+1)
            DO 2080 IC = 1, 3
              VERT(IC,IV,I) = VERT(IC,IV,I+1)
              CENTR(IC,IV,I) = CENTR(IC,IV,I+1)
 2080 continue
 2070 continue
 2060 continue
        NTS = NTS - 1
        ITS = ITS - 1
      ENDIF
      IF(ITS.LT.NTS) GOTO 450
C***********************************************************
C     Calcola il volume della cavita' con la formula (t. di Gauss):
C                V=SOMMAsulleTESSERE{A r*n}/3
C     dove r e' la distanza del punto rappresentativo dall'origine,
C     n e' il versore normale alla tessera, A l'area della tessera,
C     e * indica il prodotto scalare.
C***********************************************************
      VCav = ZERO
      DO 2090 ITS = 1, NTS
        NSFE = ISPHE(ITS)
C     Trova il versore normale
        XN = (XCTS(ITS) - XE(NSFE)) / RE(NSFE)
        YN = (YCTS(ITS) - YE(NSFE)) / RE(NSFE)
        ZN = (ZCTS(ITS) - ZE(NSFE)) / RE(NSFE)
C     Trova il prodotto scalare
        PROD = XCTS(ITS)*XN + YCTS(ITS)*YN + ZCTS(ITS)*ZN
        VCav = VCav + AS(ITS) * PROD / 3.D0
 2090 continue
C***********************************************************
C     Stampa la geometria della cavita'
      Scav=ZERO
      DO 500 I=1,NESF
 500  SSFE(I)=ZERO
      DO 510 I=1,NTS
      K=ISPHE(I)
 510  SSFE(K)=SSFE(K)+AS(I)
      OMEGA=OMEGA/FIRST
      IF(IPRINT.EQ.2) WRITE(6,1100)OMEGA,RSOLV,RET,FRO,NESF
           DO 520 I=1,NESF
      IF(IPRINT.EQ.2)WRITE(6,1200)I,XE(I),YE(I),ZE(I),
     * RE(I),SSFE(I)
 520  Scav=Scav+SSFE(I)
      IF(IPRINT.EQ.2)WRITE(6,1300)NTS,Scav,VCav
C
C     Trasforma i risultati in bohr
      DO 2170 I=1,NESF
        RE(I)=RE(I) / ToAng
        XE(I)=XE(I) / ToAng
        YE(I)=YE(I) / ToAng
        ZE(I)=ZE(I) / ToAng
 2170 continue
      DO 2180 I=1,NTS
        DO 2190 J=1,NVERT(I)
          DO 2200 L=1,3
            VERT(L,J,I) = VERT(L,J,I) / ToAng
            CENTR(L,J,I) = CENTR(L,J,I) / ToAng
 2200 continue
 2190 continue
 2180 continue
      DO 2210 I=1,NTS
        AS(I)=AS(I) / (ToAng*ToAng)
        XCTS(I)=XCTS(I) / ToAng
        YCTS(I)=YCTS(I) / ToAng
        ZCTS(I)=ZCTS(I) / ToAng
 2210 continue
      IF(IPRINT.EQ.3)THEN
      WRITE(6,1500)
      WRITE(6,1600)
      WRITE(6,1700)(I,ISPHE(I),AS(I),XCTS(I),YCTS(I),ZCTS(I),
     *              I = 1, NTS)
      ENDIF
      If(NN1.gt.MxTs) then
        Write(6,1240) NN1, MxTs
 1240   Format(' NN1=',I10,' but MxTs=',I10,'.')
        Write(6,1112)
 1112   format('Too many tesserae.')
        Call Abend
        endIf

      RETURN
 800  FORMAT(/,'**** POLARISABLE CONTINUUM MODEL - UNIVERSITIES',
     & ' OF NAPLES AND PISA *****')
1000  FORMAT(/,'ATTENZIONE: I CENTRI DELLE TESSERE ',I4,',',I4,
     *  ' DISTANO MENO DI',F8.6,' A',/)
1100  FORMAT(/,'** CHARACTERISTICS OF THE CAVITY **',
     * //, '  GEOMETRICAL PARAMETERS: OMEGA=',F8.3,' RSOLV=',F8.3,
     * ' RET=',F8.3,' FRO=',F8.3,
     * //,'  TOTAL NUMBER OF SPHERES',I5,//,'  CENTERS AND RADII :',//,
     *       '  SPHERE       CENTER  (X,Y,Z) (A)     RADIUS (A)',
     * '       AREA(A*A)')
c1200  FORMAT(I5,4F15.9,F18.9)
1200  FORMAT(I5,4F10.3,F18.3)
1300  FORMAT(/,' TOTAL NUMBER OF TESSERAE ',I8,//,
     *' SURFACE AREA',F14.8,'(A**2)',8X,'CAVITY VOLUME',
     * F14.8,' (A**3)')
*1400  FORMAT(/,'SFERA',I4,' COORD.',I4,'  DERIVATA   ',F10.6,/)
1500  FORMAT('1 *** SUDDIVISIONE DELLA SUPERFICIE  ***')
1600  FORMAT(' TESSERA  SFERA   AREA   X Y Z CENTRO TESSERA  ',
     * 'X Y Z PUNTO NORMALE')
1700  FORMAT(2I4,7F12.7)
*1800  FORMAT(/,'**** END OF CAVITY DEFINITION ****',/)
c Avoid unused argument warnings
      IF (.FALSE.) CALL Unused_integer(NAT)
      END
