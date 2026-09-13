# PR3 — configuration scalaire complète (défauts de l'exécutable)

Généré par `outils/config_defauts.py` (lit ta copie locale de PR3, jamais commitée).
Pour chaque appel aux loaders de config de l'exe (`0x89D6E0` int, `0x89D750` flt,
`0x89D7C0` i[], `0x89D8A0` f[], `0x89E270` str), on relève **section, clé, type,
et le DÉFAUT** poussé.

Lecture :
- `= <valeur>` : le défaut codé dans l'exe. **Pour les scalaires, c'est presque
  toujours la valeur du jeu** (il n'existe pas de fichier de config texte qui les
  écrase ; `constdata.dat` ne stocke pas ces clés en clair).
- `i[]` / `f[]` sans valeur : **tableaux** dont les valeurs vivent dans les TABLES
  BINAIRES de `constdata.dat` (navires, munitions, prix des canons, coûts
  d'agrandissement…), à parser table par table (voir `PR3_SYSTEMES.md`).

C'est la « bible » des réglages : 146 sections, 421 clés. Tout ce qui suit est
tiré des fichiers, rien d'inventé.

== 146 sections, 421 cles (avec defaut quand lisible)

[Abwanderung]
   Arbeiter : f[]
   Pesttote : f[]
[AccelerationMax]
   AccelerationMin : flt = 0
[AccelerationMin]
   RotXMax : flt = 0
[AccelerationTime]
   AccelerationMax : flt = 0
[Advisor]
   HintTown : int
   HintConvoy : int
   hint%u : int
   Notification : str
   HintShip : str
   HintTown%02u : str
   Tip%02d : str
[Aktion]
   Text : int = 11768912
[AllowTilt]
   AccelerationTime : int
[AmmoData]
   Vmax_%d : flt = -1
   DmgHull_%d : int
[AmmoTrajectory]
   Gravity : flt = 10
   Amax : flt = 30
   ACorrMax : flt = 5
   FiringDelay : flt = 6
   ScatterMin : flt = 0.98
   ScatterMax : flt = 1.02
   AAimMax : flt = 2
[Anchorage]
   Offset : flt = 30
[Attraction]
   A1 : flt = 1.5
   B1 : flt = 1
   C1 : flt = 1
   D1 : flt = 1
[AusbauKosten]
   Upgrade_Shipyard : i[]
[AusbauWaren]
   Upgrade_Shipyard : i[]
[Autosave]
   Timer : int
[BattleAsset]
   Wendig : str
[BattleShip]
   Acceleration : flt = 0.25
   Speed : flt = 8
   TurnSpeed : flt = 0.25
   ShootAngle : flt = 0.261799
   ReloadTime : flt = 5
   SinkSpeed : flt = 2.5
[Battleship]
   MaxTurn : flt = 90
   MaxAccel : flt = 1
   ReloadTime : flt = 5
   NavigationFactor : flt = 0.05
   TurnSpeedFactor : flt = 0.3
   SinkSpeed : flt = -0.01
   SpeedFactor : flt = 1
[Baukosten Betriebe]
   Bauplatzkosten : i[]
[Bauplatzfaktor]
   Faktor : f[]
[Bauquotient_Mod]
   Ware%u_MOD : flt = 1
   Neubauwert : i[]
[BeggarsMax]
   MarketVisitsMax : int
[Boarding]
   Prepare : flt = 7
   Start : flt = 3.5
   Steps : int
   DmgMod : flt = 5
   HpModMax : flt = 3
   DmgMuskets : flt = 2
   DmgCutlass : flt = 1
   DmgUnarmed : flt = 0.7
   HpMuskets : flt = 5
   HpCutlass : flt = 10
   HpUnarmed : flt = 10
   MaxSpeed : flt = 25
   CloseUpSpeed : flt = 5
   MaxOffset : flt = 10
[Builder]
   Spacing : flt = 30
   SpeedMul : flt = 2.8
   SpeedAdd : flt = 0.2
   RotateMaxVal : i[]
[Buildings]
   Default : str
   EventGroup : str
   GroupIndex : int = 0
   DefaultScale : flt = 1
   TranslationScale : flt = 0
[Captain]
   Damage : f[]
   Boarding : f[]
[Colors]
   MinimapTown : f[]
[Construct]
   DailyCosts : i[]
[DailyCosts]
   Gauge : int = 0
[Data]
   towns : int = 0
   production_per_town : int = 0
   1Fass : int = 1000
   Grundkosten : int = 50
   Lohn : int = 5
   Heuer : int = 2
   VerwalterLohn : int = 50
   VorratTage : int = 15
   NeubauOfficeVorratTage : int = 5
   NeubauWeltVorratTage : int = 15
   NeubauMinAlq : int = 50
   StartFabriken : int = 20
   MinAreaFactor : int = 10
   Faktor : flt = 1
   Lagermiete : f[]
   BasicCapacity : int = 1000
[Datum]
   entry%u : i[]
[Delay]
   vector<T> too long : flt = 0
[Delta]
   Speed : flt = 0
[Difficulty]
   RepFactor : f[]
   Create : f[]
   Receive : f[]
[Dog]
   Quota : flt = 0.05
[Donation]
   Ansehen : flt = 0.01
   Pay : int = 10
   Steps : int = 2
[DropGoods]
   Time : int = 10
[EffectSystem]
   MaxParticles : int = 0
   TicksPerSec : int = 30
[Equipment]
   PriceStandard : i[]
   PricePirates : i[]
[EventCount]
   FadeOut : int
[EventGroup]
   FadeOut : str
[Export]
   ExportYMin : int = 0
   ExportYMax : int = 700
   ExportXMin : int = 650
   ExportXMax : int = 1200
[FadeIn]
   Delay : flt = 0
[FadeOut]
   FadeIn : flt = 0
[FarDist]
   NearDist : flt = 20
[FastFactor]
   MinHeight : flt = 4
[Flags]
   Nations : i[]
[Flotsam]
   Markerabstand : int = 10
   CastawayReward : int = 100
   CastawayRewardHome : int = 1000
[Fortress]
   Range : flt = 100
   ReloadTime : flt = 0
   Hit : i[]
   Data_%u : f[]
   Gun_%u_%02u : f[]
[Fov]
   FarDist : flt = 90
[Game]
   LockCamera : int
   Tooltips : int
   EventVideos : int
   AdvisorVideos : int
   PauseTrade : int
   Demo : int
   UseGamePad : int
   Vibration : int
   AutoSaveEnabled : int
   RepeatTimeout : flt
   RepeatTimeoutInitial : flt
   HoldTimeout : flt
   BattlespeedMultiplayer : int
[GameSpeed]
   StepLimit : int = 50
[GameStart]
   Year : i[]
   Month : i[]
   Day : i[]
[Gauge]
   Masts : int = 0
[Global]
   StepsPerSec : int = 10
   Geschwindigkeit : flt = 2
   WaterPlaneOffset : flt = 63.5
[Goods]
   Town%u : i[]
[Grasshopper]
   Months : i[]
   SpeedMin : flt = 25
   SpeedMax : flt = 35
   Radius : int = 47
   Asset : str
[Grundbedarf]
   Ware%02u_GB : int
[Gui]
   SpeedFactor : flt = 0.25
   SeaMapWidth : int = 1024
   SeaMapHeight : int = 512
   SeaMapOffsetX : int = 0
   SeaMapOffsetZ : int = 0
   SelectionRange : flt = 16
   SelectionRangeTown : flt = 11
[GuildPrivilege]
   priv%u : f[]
[Hausbau Waren]
   Hausbau Kosten : i[]
[HitpointsSail]
   Hitpoints : int = 0
[HullDamage]
   Condition_%d : flt = -1
   SpeedFactor_%d : flt = 1
[HullHeight]
   HullWidth : flt = 0
[HullWidth]
   HullLength : f[]
[Info]
   Aktion : int = 255
[Init]
   ActivateSound : str
   Project : str
   MediaPath : str
   TownCount : int = 0
   MaxVirtualChannels : int = 0
   Max3DHardwareChannels : int = 0
   LoadingScreenFadeTime : flt = 0.6
[Initial]
   Konvois : int = 3
   Offset : flt = 75
   FormationZ : flt = 20
[Kampagne]
   Video : i[]
[Language]
   Language : str
[Lebensqualitaet]
   EventElq : flt = 39
[Licence]
   Rank : int = 10
   RepNation : int = 5
   RepTown : int = 5
   Buildings : int = 3
[Limits]
   maxConvoys : int = 100
   maxConvoyMembers : int = 50
   maxShips : int = 50
[MarketVisitsMax]
   MarketVisitsMin : int
[MaxCount]
   IdleTime : int = 1
[MaxDist]
   MinDist : flt = 20
[MinDist]
   ZoomScale : flt = 10
[MinHeight]
   TiltYOffset : flt = 20
[MinRank]
   MaxCount : int = 1
   Hospital : int = 10
   ShipYard : int = 12
[Mine]
   Asset : str
   LifeTime : flt = 8
   ReloadTime : flt = 0.7
   DetectorDist : flt = 5
   DamageDist : flt = 50
   DamageFactor : flt = 0.3
[Minimalmengen]
   Ware%u : int
[MinimapPos]
   Stadt%u : i[]
[MissionDuration]
   DisplayDuration : int = 1
[Multiplayer]
   StartGold%d : int
   StartShips%d : i[]
   GoalWealth%d : int
   GoalShips%d : int
   GoalTime%d : int
   GoalHomeTown%d : int
   GoalBuildings%d : int
   GoalDepots%d : int
   GoalOwnTowns%d : int
   PvPBattleStartTimer : int = 8
   PvPBattleDecisionTimer : int = 10
   PvPBattleResultTimer : int = 5
[NationReputation]
   Annexed : int = 200
[NearDist]
   MaxDist : flt = 10
[Network]
   Username : str
   PublicGame : int = 0
   VoiceChat : int = 0
   ChatDisplayTime : int
[NewGame]
   Emblems : int = 10
   Avatars : int = 16
[Obstacle]
   Min : int = 3
   Delta : int = 7
[Patrol]
   Asset : str
   Factor : f[]
[Pig]
   Quota : flt = 0.05
[Pirate]
   SailorMod : f[]
   StartGold : int = 50000
   StartSailors : int = 500
   StartShips : i[]
   GoodsFactor : flt = 2
   CannonStore : i[]
   EKS : flt = 0
[Pirates]
   Activity : i[]
   TownAttackDist : int = 200
   TownAttackLock : int = 17
[Player]
   Gold : int = 10000
   Home : int = 47
   ShipType : int = 0
[Preisfaktoren]
   X%u : f[]
[Repairs]
   Zeit : flt = 30
   Kosten : int = 50
[Reputation]
   Offset : f[]
   Amplitude : f[]
   Phase : f[]
[Residential]
   Rent : f[]
   Renter : int = 100
   FillRate : int = 65
   Unterhalt : int = 50
   Wohlstand%u : i[]
[Roads]
   TownRoadWidthScale : flt = 8
[Rohstoffbedarf]
   Ware%02u_Bedarf : i[]
   Rohstoffbedarf : f[]
[RotXMax]
   RotXMin : flt = 89
[RotXMin]
   Fov : flt = 1
[SailDamage]
   SpeedFactor_%d : flt = 1
[SailHeight]
   SailLength : flt = 0
[SailLength]
   SailOffset : f[]
[SailOffset]
   HullHeight : f[]
[SailType]
   SailHeight : i[]
[Sailor]
   Asset : str
   CorpseAsset : str
   DropChance : flt = 0.2
   LifeTime : flt = 120
   FallTime : flt = 1.5
   PickupDist : flt = 5
[Sails]
   maxAngles : f[]
   minAngles : f[]
   Transform%u : str
   SetSailsTime : flt = 6
[Schatzflotte]
   Bettlerfaktor : flt = 1.4
[SeaMapMovement]
   SpeedFactor : flt = 0.1
   RangeOfVision1 : int = 8
   RangeOfVision2 : int = 12
   RangeOfVisionWatch : int = 12
[Seabattle]
   Situation%02u : str
[Settings]
   MinNumBirdCritterSwarms : int = 0
   MaxNumBirdCritterSwarms : int = 0
   MinNumBirdCritterPerSwarm : int = 0
   MaxNumBirdCritterPerSwarm : int = 0
   MinNumFishCritter : int = 0
   MaxNumFishCritter : int = 0
[Shark]
   Asset : str
   Radius1 : flt = 10
   Speed : flt = 10
   Splash0 : flt = 1.5
   Splash1 : flt = 1.5
   KillTime : flt = 1.5
   SpawnRadius : flt = 50
[Ship]
   CrewmenAtGun : int = 5
[Singleplayer]
   BattleStartTimer : flt = 8
   BattleIdleTimer : flt = 3
   StartCapital%d : i[]
[Soldier]
   MovementFactor : flt = 1
   EvadeSpeed : flt = 2
   InteractStand : flt = 1.5
   InteractMove : flt = 1.2
   UnitSize : int = 10
   UnitMax : int = 225
   Damage : f[]
   Health : f[]
   Range : f[]
   RangeFactor : flt = 1.4
   Speed : f[]
[Sound]
   Sound : int
   MovieTrack : int
   MovieTrackFallback : int
   VoiceFilter : int
   VoiceVBR : int
   VoiceQuality : int
   MicrophoneGain : int
[SoundRegion]
   Region : int = 0
[SpecialEdition]
   OfficeAsset : str
   OfficeAssetSp : str
[Speed]
   Asset : flt = 1
[Stadtliste]
   initial : int = 10
[StandardPaymentValue]
   spv%u : i[]
[Standardpreise]
   Ware%02u_SWP : int
[Storm]
   Speed : flt = 30
   SpeedRotation : flt = 0.2
   TurnAngle : flt = 6
   Months : i[]
   Radius : int = 47
   Asset : str
[Tactic]
   MaxFleeDist : flt = 1000
   SecUpdateSupport : flt = 10
   SecUpdateFleetAi : flt = 30
[Terrain]
   HeightmapResolution : int = 1024
   Variant : int = 0
   Scale : f[]
   Material : str
   SkyMaterial : str
   FoliagePool : str
   FoliageSpan : str
   Background : str
   BackgroundTfm : f[]
   GridOrientation : flt = 0
[TiltAtZoom]
   AllowTilt : flt = 0
[TiltYOffset]
   TiltAtZoom : flt = 0
[Time]
   Verkaufszeit : int = 64
   Einkaufszeit : int = 64
   Einlaufzeit : int = 128
   KiUpdateConvoySize : int = 7680
   StepsPerSec : int = 20
[TimeSteps]
   PreSteps : int = 23040
[Timer]
   Idle : flt = 5
   SeaBattle : int = 120
   SoldierLeave : int = 5
   ShipLeave : int = 15
[TownDeco]
   Variant%d_%d : i[]
   RemovalDist : flt = 1
[TownType]
   MinRank : int = 12
[TownView]
   Grass : int
   Shadow : int
   CloudShadow : int
   Details : int
   FoliageDensity : flt = 0
   AnchorPointOffset : flt = 12
   AnchorPointLength : flt = 100
[Treasure]
   offsetX : int = 87
   offsetY : int = -2
   scaleX : flt = 1.4186
   scaleY : flt = 1.4186
   StartX : int = 140
   StartY : int = 120
   EndX : int = 220
   EndY : int = 180
   minPosY1 : int = 44
   minPosY2 : int = 77
   maxPosY1 : int = 914
   maxPosY2 : int = 886
[Value]
   HitpointsSail : int = 0
[Verbrauch]
   Pest : int = 100
   Heuschrecken : int = 100
   Feuer : int = 100
   FeuerSpread : i[]
[Video]
   WindowedHeight : int
   WindowedRate : int
   FullScreenWidth : int
   FullScreenHeight : int
   FullScreenRate : int
   ShaderPerformance : int
   FullScreen : int
   PostEffects : int
   VSync : int
   Anisotropy : int
   Antialiasing : int
   UseFoliageLod : int
   FoliageLodFadeMin : flt
   FoliageLodFadeMax : flt
   UIUpscaling : int
   Aspect : str
   Credits : str
   Publisher : str
   Event%02d_%02d : str
   Mission%02d : str
   Tutorial%02d : str
   Event%02d : str
   Advisor%02d : str
   Viceroy%02u_%02d : str
   Admin%02u_%02u : str
   Intro : str
   Boot : str
   Info : int = 0
[Warenverbrauch]
   Ware%02u_Verbrauch : flt = 0
[Weather]
   Region%uRain : i[]
   CloudLayer : str
[ZoomScale]
   ZoomStep : flt = 0.1
[ZoomSpeed]
   TurnSpeed : flt = 4
[ZoomStep]
   ZoomSpeed : flt = 0.1
[maxRankMil]
   minRankMil : int = 0
[minRankMil]
   Value : int = 10000
[minRankPir]
   maxRankMil : int = 255
