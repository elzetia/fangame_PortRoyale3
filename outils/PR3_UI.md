# PR3 — structure des écrans (UI Flash/Iggy)

Généré par `outils/swf_ui.py` (lit ta copie locale). Par écran `.swf` : la scène,
le CATALOGUE de composants (SymbolClass), et les PLACEMENTS nommés (instance,
classe, position en px). Aucune image extraite (droits) — c'est la structure pour
recréer les écrans dans Godot, à l'identique de PR3.

Les positions sont désormais exactes (twips→px). Les champs texte internes (`tf_*`)
sont définis dans les sous-SWF de composants et n'apparaissent pas ici ; leurs NOMS
d'instance figurent dans les placements.

================================================================
# ingame_radial_town.swf  scene 2880x2880 px
  classe 47: scenes.Scene_Radial_Town
  classe 46: ingame_radial_town_fla.Group_Radial_Elements_7
  classe 45: ingame_radial_town_fla.Group_Radial_Palace_19
  classe 44: ingame_radial_town_fla.Group_Radial_Tavern_18
  classe 43: ingame_radial_town_fla.Group_Radial_Church_17
  classe 42: ingame_radial_town_fla.Group_Radial_Storage_16
  classe 41: ingame_radial_town_fla.Group_Radial_Harbourmaster_13
  classe 38: ingame_radial_town_fla.Group_Radial_Shipyard_12
  classe 37: ingame_radial_town_fla.Group_Radial_Center_10
  classe 36: ingame_radial_town_fla.Group_ProdGoods_11
  classe 35: ingame_radial_town_fla.Group_Radial_Town_8
  classe 32: ingame_radial_town_fla.Icon_Towns_Big_9
  classe 3: components.customrenderelement.Visual_CR_Radial
  classe 0: gm.rootElement
  19 sprites, 68 placements nommes, 0 champs texte
  -- placements nommes (position en px) --
    mc_bg                              @(0,0) x1 <char2>
    RAD_LEFT                           @(57,262) x1 <char6>
    RAD_DOWNLEFT                       @(117,409) x1 <char6>
    RAD_DOWN                           @(264,470) x1 <char6>
    RAD_DOWNRIGHT                      @(411,409) x1 <char6>
    RAD_RIGHT                          @(472,262) x1 <char6>
    RAD_UPLEFT                         @(117,116) x1 <char6>
    RAD_UPRIGHT                        @(411,116) x1 <char6>
    townstate                          @(63,25) x1 <ingame_radial_town_fla.Icon_Towns_Big_9>
    gr_goods                           @(-65,59) x1 <ingame_radial_town_fla.Group_ProdGoods_11>
    icon_ships                         @(13,0) x1 <char39>
    icon_convoys                       @(1,62) x1 <char40>
    town                               @(272,99) x1 <ingame_radial_town_fla.Group_Radial_Town_8>
    center                             @(300,293) x1 <ingame_radial_town_fla.Group_Radial_Center_10>
    shipyard                           @(495,334) x1 <ingame_radial_town_fla.Group_Radial_Shipyard_12>
    harbour                            @(120,280) x1 <ingame_radial_town_fla.Group_Radial_Harbourmaster_13>
    storage                            @(94,94) x1 <ingame_radial_town_fla.Group_Radial_Storage_16>
    church                             @(313,592) x1 <ingame_radial_town_fla.Group_Radial_Church_17>
    tavern                             @(461,460) x1 <ingame_radial_town_fla.Group_Radial_Tavern_18>
    palace                             @(95,460) x1 <ingame_radial_town_fla.Group_Radial_Palace_19>
    cr_bg                              @(0,0) x1 <components.customrenderelement.Visual_CR_Radial>
    disable                            @(0,0) x1 <char7>
    selection                          @(0,0) x1 <char17>
    elements                           @(0,0) x1 <ingame_radial_town_fla.Group_Radial_Elements_7>
  -- champs texte (bounds px, variable) --

================================================================
# dialog_convoy_town_pc.swf  scene 2880x2880 px
  classe 56: scenes.Scene_Convoy_Town
  classe 55: components.animatedelement.Visual_AniElement_Sortbar_Advisor
  classe 54: components.focuselement.Visual_Tab_Buttons_Pad
  classe 53: components.focuselement.Visual_Tab_Buttons_Mouse
  classe 52: exports.Text_Focus_Input
  classe 47: scenes.Scene_Convoy_Town_Console
  classe 46: exports.Tab_patrol
  classe 45: dialog_convoy_town_pc_fla.group_convoydetails_26
  classe 44: dialog_convoy_town_pc_fla.group_lastFight_25
  classe 43: exports.Tab_TradingRoutes02
  classe 42: dialog_convoy_town_pc_fla.group_routedetails_23
  classe 41: dialog_convoy_town_pc_fla.group_routeInfos_Sum_22
  classe 34: dialog_convoy_town_pc_fla.group_routeInfo_Alltime_21
  classe 33: dialog_convoy_town_pc_fla.Tab_Piracy_9
  classe 32: dialog_convoy_town_pc_fla.group_piracy_last_11
  classe 31: dialog_convoy_town_pc_fla.group_piracy_all_10
  classe 30: exports.Tab_ConvoyList
  classe 29: components.animatedelement.Visual_AniElement_Sortbar_Convoy
  classe 28: components.button.Visual_IconButton_SortAToZ
  classe 24: components.list.Visual_List_Convoy
  classe 23: exports.Tab_advisor
  classe 22: components.list.Visual_List_AdvisorHints
  classe 21: exports.Tab_TownList
  classe 20: components.animatedelement.Visual_AniElement_Sortbar_Town
  classe 19: components.list.Visual_List_Towns
  classe 18: exports.Tab_ShipList
  classe 17: components.animatedelement.Visual_AniElement_Sortbar_Ship
  classe 16: dialog_convoy_town_pc_fla.Icons_Arrow_UpDown_8
  classe 9: components.list.Visual_List_Ships
  classe 5: icon_shippreview_caravel.png
  classe 4: icon_shippreview_carrack.png
  classe 3: icon_shippreview_military_corvette.png
  classe 2: icon_shippreview_military_frigate.png
  classe 1: icon_shippreview_piratebarc.png
  classe 0: gm.rootElement
  31 sprites, 237 placements nommes, 0 champs texte
  -- placements nommes (position en px) --
    sort_dir                           @(358,4) x1 <dialog_convoy_town_pc_fla.Icons_Arrow_UpDown_8>
    li_ships                           @(0,90) x1 <components.list.Visual_List_Ships>
    sortbar                            @(0,68) x1 <components.animatedelement.Visual_AniElement_Sortbar_Ship>
    sort_dir                           @(358,4) x1 <dialog_convoy_town_pc_fla.Icons_Arrow_UpDown_8>
    li_towns                           @(0,90) x1 <components.list.Visual_List_Towns>
    sortbar                            @(0,68) x1 <components.animatedelement.Visual_AniElement_Sortbar_Town>
    li                                 @(0,74) x1 <components.list.Visual_List_AdvisorHints>
    button_set                         @(0,0) x1 <char25>
    sort_alpha                         @(172,1) x1 <components.button.Visual_IconButton_SortAToZ>
    sort_dir                           @(358,4) x1 <dialog_convoy_town_pc_fla.Icons_Arrow_UpDown_8>
    li_convoys                         @(0,90) x1 <components.list.Visual_List_Convoy>
    sortbar                            @(0,68) x1 <components.animatedelement.Visual_AniElement_Sortbar_Convoy>
    grp_1                              @(0,360) x1 <dialog_convoy_town_pc_fla.group_piracy_all_10>
    grp_0                              @(0,206) x1 <dialog_convoy_town_pc_fla.group_piracy_last_11>
    info_all                           @(0,400) x1 <dialog_convoy_town_pc_fla.group_routeInfo_Alltime_21>
    info_last_detail                   @(-1,194) x1 <dialog_convoy_town_pc_fla.group_routeInfos_Sum_22>
    info_last                          @(-1,194) x1 <dialog_convoy_town_pc_fla.group_routedetails_23>
    info_last_battle                   @(0,401) x1 <dialog_convoy_town_pc_fla.group_lastFight_25>
    info                               @(1,158) x1 <dialog_convoy_town_pc_fla.group_convoydetails_26>
    tab_6                              @(20,63) x1 <exports.Tab_ShipList>
    tab_5                              @(20,63) x1 <exports.Tab_TownList>
    tab_4                              @(20,79) x1 <exports.Tab_advisor>
    tab_3                              @(20,63) x1 <exports.Tab_ConvoyList>
    tab_2                              @(20,64) x1 <dialog_convoy_town_pc_fla.Tab_Piracy_9>
    tab_1                              @(20,64) x1 <exports.Tab_TradingRoutes02>
    tab_0                              @(20,64) x1 <exports.Tab_patrol>
    sort_dir                           @(358,4) x1 <dialog_convoy_town_pc_fla.Icons_Arrow_UpDown_8>
    tab_0                              @(20,63) x1 <exports.Tab_ConvoyList>
    tab_1                              @(20,64) x1 <dialog_convoy_town_pc_fla.Tab_Piracy_9>
    tab_2                              @(20,63) x1 <exports.Tab_ShipList>
    tab_3                              @(20,63) x1 <exports.Tab_TownList>
    tab_4                              @(20,79) x1 <exports.Tab_advisor>

================================================================
# hud_pc.swf  scene 2880x2880 px
  classe 177: scenes.scene_hud.Scene_Hud
  classe 176: Hud_pc_fla.Hud_Woodboard_Left_PC_68
  classe 175: Hud_pc_fla.Group_Bottom_Right_30
  classe 174: Hud_pc_fla.Hud_Woodboard_Right_3
  classe 173: Hud_pc_fla.HUD_Woodboard_Right_BG_4
  classe 170: scenes.scene_hud.Visual_UnfocusedBtn_Container
  classe 169: pr3.minimap.Visual_IconButton_Seabattle
  classe 168: Hud_pc_fla.Buttonset_Seabattle_73
  classe 161: exports.Help_Bg
  classe 150: scenes.scene_hud.Scene_Hud_Console
  classe 149: Hud_pc_fla.Group_Unfocused_Input_70
  classe 148: Hud_pc_fla.Hud_Scroll_Top_50
  classe 144: Hud_pc_fla.Group_Nations_Reputationmarker_66
  classe 143: Hud_pc_fla.Icon_Nation_Relation_67
  classe 138: Hud_pc_fla.Hud_Scroll_Top_Town_57
  classe 137: Hud_pc_fla.Hud_Scroll_Top_Town_Icons_64
  classe 136: components.textbutton.Visual_TextButton_Top_Townname
  classe 135: Hud_pc_fla.Buttonset_Text_Top_Townname_59
  classe 134: Hud_pc_fla.TextButton_Top_Townname_Over_63
  classe 131: Hud_pc_fla.TextButton_Top_Townname_Pressed_62
  classe 128: Hud_pc_fla.TextButton_Top_Townname_Disabled_61
  classe 127: Hud_pc_fla.TextButton_Top_Townname_Normal_60
  classe 123: Hud_pc_fla.Group_Pirate_Trend_54
  classe 122: components.button.Visual_IconButton_Pirate_Trend
  classe 121: Hud_pc_fla.Icons_Pirate_Trend_56
  classe 110: Hud_pc_fla.Group_Plunder_Info_52
  classe 109: exports.Visual_Plunder_Info
  classe 105: Hud_pc_fla.Hud_Scroll_Right_Elemente_33
  classe 104: Hud_pc_fla.Group_Right_Convoy_Name_State_45
  classe 103: components.textbutton.Visual_TextButton_Convoyname
  classe 102: Hud_pc_fla.Buttonset_Text_Convoyname_48
  classe 97: Hud_pc_fla.Maske_Textbutton_49
  classe 95: Hud_pc_fla.Visual_Convoy_Task_46
  classe 94: Hud_pc_fla.Group_Right_Convoy_Details_44
  classe 93: Hud_pc_fla.Visual_List_Goods_43
  classe 90: Hud_pc_fla.Group_Convoy_Battleship_Details_41
  classe 89: Hud_pc_fla.Visual_List_Bships_42
  classe 86: Hud_pc_fla.Hud_Scroll_Right_Elemente_Kapitaene_Details_39
  classe 82: Hud_pc_fla.Hud_Scroll_Right_Elemente_Route_36
  classe 81: Hud_pc_fla.Hud_Scroll_Right_Elemente_Route_New_38
  classe 80: Hud_pc_fla.Hud_Scroll_Right_Elemente_Route_Details_37
  classe 79: Hud_pc_fla.Hud_Scroll_Right_Elemente_Pirate_35
  classe 78: Hud_pc_fla.Group_Right_Convoy_Details_Console_Legend_34
  classe 74: Hud_pc_fla.Hud_Woodboard_Left_Console_80
  classe 73: exports.Group_Scenario_Info
  classe 70: components.button.Visual_IconButton_Player_Progress
  classe 69: components.animatedelement.Visual_AniElement_XP_Bar
  classe 57: Hud_pc_fla.HUD_Woodboard_Left_Top_Console_81
  classe 54: scenes.scene_hud.Visual_TooltipContainer
  classe 53: Hud_pc_fla.Hud_Woodboard_Right_Console_76
  classe 52: components.customrenderelement.Visual_CustomRender
  classe 50: Hud_pc_fla.Icon_Anchored_79
  classe 47: Hud_pc_fla.Icon_OnSea_78
  classe 44: pr3.minimap.Visual_Minimap_Mc_Objects
  classe 43: Hud_pc_fla.Minimap_Steadte_Liste_14
  classe 42: components.button.Visual_Button_Minimap_Town
  classe 41: Hud_pc_fla.Buttonset_Minimap_16
  classe 40: Hud_pc_fla.minimap_konvoi_in_stadt_20
  classe 37: Hud_pc_fla.minimap_stadt_kontor_19
  classe 23: Hud_pc_fla.Maske_Roundbutton_17
  classe 21: pr3.minimap.Visual_Minimap_Frame
  classe 19: Hud_pc_fla.Mask_Standard_11
  classe 18: components.button.Visual_Button_Minimap
  classe 17: components.customrenderelement.Visual_CustomRender_Minimap
  classe 11: Hud_pc_fla.Buttonset_Mask_6
  classe 10: Hud_pc_fla.Maske_Standard_7
  classe 8: Hud_pc_fla.HUD_Woodboard_Right_BG_Console_77
  classe 5: icon_shippreview_caravel.png
  classe 4: icon_shippreview_carrack.png

================================================================
# dialog_route_details.swf  scene 2880x2880 px
  classe 43: scenes.Scene_Route_Townlist
  classe 42: dialog_route_details_fla.Group_Goods_12
  classe 41: dialog_route_details_fla.Group_Control_Price_16
  classe 40: dialog_route_details_fla.Group_Control_Amount_14
  classe 33: exports.Dialog_Tabless_SlimHead_Wide_PC
  classe 32: dialog_route_details_fla.Dialog_BG_Wide_PC_3
  classe 29: components.list.Visual_List_Route_Towns
  classe 28: components.button.Visual_ListButton_Route_Town
  classe 27: dialog_route_details_fla.Buttonset_ListButton_Route_Town_8
  classe 22: dialog_route_details_fla.Icons_Route_Options_9
  classe 18: exports.Text_Focus_Input
  classe 13: components.list.Visual_List_Lock_Goods
  classe 10: components.textbutton.Visual_Textbutton_Select_Mode
  classe 9: dialog_route_details_fla.Buttonset_Select_Mode_18
  classe 5: Container_LokaIcons
  classe 4: icon_route_convoy2town
  classe 3: icon_route_town2convoy
  classe 2: icon_route_convoy2office
  classe 1: icon_route_office2convoy
  classe 0: gm.rootElement
  20 sprites, 99 placements nommes, 0 champs texte
  -- placements nommes (position en px) --
    button_set                         @(0,0) x1 <dialog_route_details_fla.Buttonset_Select_Mode_18>
    bg                                 @(0,0) x1 <char21>
    icons                              @(12,11) x1 <dialog_route_details_fla.Icons_Route_Options_9>
    hitmask                            @(0,0) x2.72 <char24>
    button_set                         @(0,0) x1 <dialog_route_details_fla.Buttonset_ListButton_Route_Town_8>
    list_item_21                       @(0,462) x1 <components.button.Visual_ListButton_Route_Town>
    list_item_20                       @(0,440) x1 <components.button.Visual_ListButton_Route_Town>
    list_item_19                       @(0,418) x1 <components.button.Visual_ListButton_Route_Town>
    list_item_18                       @(0,396) x1 <components.button.Visual_ListButton_Route_Town>
    list_item_17                       @(0,374) x1 <components.button.Visual_ListButton_Route_Town>
    list_item_16                       @(0,352) x1 <components.button.Visual_ListButton_Route_Town>
    list_item_15                       @(0,330) x1 <components.button.Visual_ListButton_Route_Town>
    list_item_14                       @(0,308) x1 <components.button.Visual_ListButton_Route_Town>
    list_item_13                       @(0,286) x1 <components.button.Visual_ListButton_Route_Town>
    list_item_12                       @(0,264) x1 <components.button.Visual_ListButton_Route_Town>
    list_item_11                       @(0,242) x1 <components.button.Visual_ListButton_Route_Town>
    list_item_10                       @(0,220) x1 <components.button.Visual_ListButton_Route_Town>
    list_item_9                        @(0,198) x1 <components.button.Visual_ListButton_Route_Town>
    list_item_8                        @(0,176) x1 <components.button.Visual_ListButton_Route_Town>
    list_item_7                        @(0,154) x1 <components.button.Visual_ListButton_Route_Town>
    list_item_6                        @(0,132) x1 <components.button.Visual_ListButton_Route_Town>
    list_item_5                        @(0,110) x1 <components.button.Visual_ListButton_Route_Town>
    list_item_4                        @(0,88) x1 <components.button.Visual_ListButton_Route_Town>
    list_item_3                        @(0,66) x1 <components.button.Visual_ListButton_Route_Town>
    list_item_2                        @(0,44) x1 <components.button.Visual_ListButton_Route_Town>
    list_item_1                        @(0,22) x1 <components.button.Visual_ListButton_Route_Town>
    list_item_0                        @(0,0) x1 <components.button.Visual_ListButton_Route_Town>
    bg                                 @(0,0) x1 <dialog_route_details_fla.Dialog_BG_Wide_PC_3>
    li_goods                           @(0,57) x1 <components.list.Visual_List_Lock_Goods>
    controls_amount                    @(34,0) x1 <dialog_route_details_fla.Group_Control_Amount_14>
    controls_price                     @(202,0) x1 <dialog_route_details_fla.Group_Control_Price_16>
    bg                                 @(0,0) x1 <exports.Dialog_Tabless_SlimHead_Wide_PC>
    li_towns                           @(30,57) x1 <components.list.Visual_List_Route_Towns>
    goods                              @(412,88) x1 <dialog_route_details_fla.Group_Goods_12>
    bu_mode                            @(612,69) x1 <components.textbutton.Visual_Textbutton_Select_Mode>
  -- champs texte (bounds px, variable) --

================================================================
# dialog_harbourmaster.swf  scene 2880x2880 px
  classe 34: scenes.Scene_Harbourmaster_Console
  classe 33: exports.TabHarbourmasterShips
  classe 32: dialog_harbourmaster_fla.Group_Highlight_Arrows_8
  classe 31: dialog_harbourmaster_fla.Group_Arrows_Left_10
  classe 28: dialog_harbourmaster_fla.Group_Arrows_Right_9
  classe 25: dialog_harbourmaster_fla.TabShips_Selection_Bg_7
  classe 18: components.list.Visual_List_ShipTransfer_Left
  classe 17: components.list.Visual_List_ShipTransfer_Right
  classe 15: dialog_harbourmaster_fla.ornamente_5
  classe 12: exports.TabHarbourmasterEquip
  classe 11: dialog_harbourmaster_fla.Ornament_Name_14
  classe 8: components.list.Visual_List_Equipment
  classe 7: components.focuselement.Visual_Icon_Captain
  classe 4: components.focuselement.Visual_Tab_Buttons_Pad
  classe 1: components.focuselement.Visual_Tab_Buttons_Mouse
  classe 0: gm.rootElement
  17 sprites, 78 placements nommes, 0 champs texte
  -- placements nommes (position en px) --
    mc_mask                            @(14,3) x12.344 <char3>
    li_equipment                       @(-1,92) x1 <components.list.Visual_List_Equipment>
    icn_tt_0                           @(0,35) x1 <components.focuselement.Visual_Icon_Captain>
    ornament                           @(1,0) x1 <char16>
    ornament                           @(1,0) x1 <char16>
    mc_left                            @(0,0) x1 <dialog_harbourmaster_fla.Group_Arrows_Right_9>
    mc_right                           @(-14,0) x1 <dialog_harbourmaster_fla.Group_Arrows_Left_10>
    li_left                            @(13,4) x1 <components.list.Visual_List_ShipTransfer_Left>
    li_right                           @(201,4) x1 <components.list.Visual_List_ShipTransfer_Right>
    mc_selection_right                 @(252,-40) x1 <dialog_harbourmaster_fla.TabShips_Selection_Bg_7>
    mc_selection_left                  @(64,-40) x1 <dialog_harbourmaster_fla.TabShips_Selection_Bg_7>
    mc_side                            @(182,14) x1 <dialog_harbourmaster_fla.Group_Highlight_Arrows_8>
    tab_0                              @(19,139) x1 <exports.TabHarbourmasterShips>
    tab_1                              @(19,140) x1 <exports.TabHarbourmasterEquip>
  -- champs texte (bounds px, variable) --


---

## Le skin partagé (skinlib_pr3.swf) — d'où vient le look

Décodé par `outils/swf_noms.py` (table SymbolClass id→classe AS3),
`outils/swf_resoudre.py` (sprite→bitmaps feuilles), `outils/swf_formes.py`
(FillStyle/LineStyle d'une DefineShape) et `outils/swf_bitmaps.py` (extraction
des bitmaps). Les .swf de dialogue ne portent presque PAS d'art : tout le skin
(cadres, onglets, boutons, scrollbars) vit dans `skinlib_pr3.swf` — 1013 classes
exportées, 868 bitmaps, 669 sprites.

### Les cadres de dialogue sont des BITMAPS peints (pas du vectoriel)

Le fond d'un dialogue est une DefineShape à remplissage bitmap (FillStyle 0x40).
Chaque type de cadre a son bitmap plein, à sa taille native :

| Classe AS3 (skinlib)          | Bitmap | Taille   | Usage                     |
|-------------------------------|--------|----------|---------------------------|
| exports.Dialog_Big            | 845    | 748x578  | dialogue simple           |
| exports.Dialog_Tabbed_Big     | 801    | 748x578  | dialogue à onglets        |
| exports.Dialog_XXL            | 738    | 748x642  | grand dialogue            |
| Dialog_Tabbed_BG_Tabs         | 820    | 430x80   | bande d'onglets           |
| (carreau de fond)             | 714    | 16x16    | texture du parchemin      |

Conséquence pour le port : on charge ces bitmaps depuis l'install locale
(`reference_pr3/ui/skinlib_pr3/<id>.png`, ignoré par git) et on les pose en
StyleBoxTexture 9-tranches. Voir `scripts/skin_pr3.gd`. Absent l'art, repli sur
un parchemin dessiné — le comportement ne dépend jamais de l'art.

### Le contenu des onglets est monté au RUNTIME (ActionScript)

`Tab_TownInfo`, `Tab_Shipyard_build`, etc. n'ont aucun agencement statique dans
la timeline (une seule case « modif » à 0,0) : les champs, listes et icônes sont
créés par le code AS3 à partir de composants (`components.list.Visual_List_*`,
`Visual_Wealth_Text_Trend`, `customrenderelement`). Le .swf livre donc le SKIN et
les COMPOSANTS, pas des coordonnées pixel. On reconstruit l'agencement à partir
du contenu connu de chaque onglet + le modèle de données décodé.

### L'info-ville n'est pas un écran à part

`dialog_trade.swf` = `scenes.Scene_Trade`, dialogue à onglets :
**Tab_TownInfo · Tab_TownGoods · Tab_Equipment · Tab_Trade** (+ variantes
Office_Convoy / Town_Office / Pirate selon le sens d'échange). Cliquer une ville
ouvre CE dialogue ; la « fiche de ville » est son premier onglet. Composants clés :
`Visual_Wealth_Text_Trend` (prospérité + flèche), `Visual_List_Town_Goods`,
icônes de sens d'échange (`icon_trade_town_convoy/office_convoy/town_office`).
Porté par `scripts/ville_panneau.gd` (onglet Infos ville).

### Le chantier

`dialog_shipyard_pc.swf` = `scenes.Scene_Shipyard`, onglets dans l'ordre :
**Tab_Shipyard_build · _repair · _buy · _sell** (+ _sell_pirate). Cadre =
Dialog_Tabbed_Big (801). Illustration propre : `dialog_shipyard_pc/18.png`
(374x228). Porté par `scripts/chantier_panneau.gd`.

---

## Les textes : le format L10N et son hachage

Les libelles de PR3 ne sont ni dans les .swf ni dans constdata : ils vivent dans
`data_fr.fuk -> ui/locale/frfr/global.res` (752 Ko), au format maison **L10N**
v1.2. Decode par `outils/pr3_loca.py`.

```
entete : 'L10N'(4)  version(u32)  nombre(u32)
table  : `nombre` enregistrements de 12 octets : hash(u32) offset(u32) longueur(u32)
textes : UTF-16LE, ranges bout a bout apres la table
```

Piege : les `offset` sont comptes depuis la FIN de l'entete, pas depuis le debut
du fichier — il faut donc leur ajouter 12. Sans ce decalage on lit six
caracteres parasites avant chaque texte.

### Le hachage des cles

La table ne contient AUCUNE cle : chaque texte est designe par un hash u32. Les
2610 cles litterales (`ID_GUI_*`, `ID_FORMATTER_*`, `ID_STRATEGY_*`) sont dans
l'exe. Le hash a ete retrouve **par ancrage** plutot qu'en desassemblant : on
sait deja que les sept paliers de prosperite sont `ID_GUI_TOWN_WEALTH_00..07`
et valent Pauvrete…Opulence. En cherchant ces textes dans la table, leurs hashes
se sont reveles **consecutifs** (632eca4b, 4c, 4d, …, 52) — signature d'un hash
polynomial, ou changer le dernier caractere de +1 decale le resultat de +1. Il
restait a resoudre le multiplicateur contre une cible connue :

```
h = 0 ; pour chaque octet c de la cle : h = (h * 113 + c) mod 2^32
```

Verifie : `hash("ID_GUI_TOWN_WEALTH_00") = 0x632eca4b`. Applique aux 2610 cles,
il en apparie **2103 (80 %)** ; le reste sont des cles bâties au runtime par
format (`ID_..._%u`), qu'on ne peut apparier sans connaitre l'indice.

Le resultat est ecrit dans `reference_pr3/ui/agencement/textes_fr.txt` (ignore
par git : texte du jeu, sous droits) et lu par `scripts/loca_pr3.gd`.

---

## Rejouer un ecran : les trois pieges

Confrontation des captures du jeu avec les notres. Trois erreurs, toutes dans la
facon de POSER l'agencement, pas dans son extraction.

### 1. Le cadre a onglets n'est pas une tuile repetee

`exports.Dialog_Tabbed` (430 px de large, 572 de haut) se compose de :

| Bitmap | Taille | Role |
|---|---|---|
| 757 | 430x62 | bandeau de bois a coins arrondis + galon dore |
| 753 | 430x48 | parchemin uni — LA tuile a repeter |
| 777 | 430x50 | culot arrondi borde de corde doree |
| 750 | 430x50 | culot du bas, pose a y=522 |

777 et 750 sont des CULOTS, pas des tuiles : les repeter empile des plaques
arrondies au lieu de remplir le fond. Seul 753 se repete.

### 2. Un onglet porte son propre decalage

La scene pose ses pages a un point qui n'est pas (0,0) :

```
Scene_Shipyard : tab_0..tab_4  @(102,-123)
Scene_Trade    : Tab_TownInfo  @(15,113)   Tab_TownGoods @(-4,126)
                 Tab_Equipment @(15,125)   Tab_Trade     @(0,125)
```

Sans ce decalage, la grille de statistiques du chantier (y=499 et y=552) tombe
hors du cadre. Voir `EcranPR3.decalage_onglet()`.

### 3. Un Control libre n'a pas de taille

`custom_minimum_size` ne vaut que dans un conteneur. Pour un noeud pose a la
main il faut `size` — sinon les plaques `Text_Bg_Nomal` s'etirent sur toute la
largeur et les icones sortent a leur taille native. La plaque mesure 13x20 avant
l'echelle du placement ; le texte qui l'accompagne prend SA largeur.

### Ordre et visibilite des onglets

L'ordre d'affichage suit l'indice du .swf, pas l'ordre des classes :
`tab_0 sell, tab_2 buy, tab_3 repair, tab_4 build` — soit **Vendre, Acheter,
Reparer**, et « Contrat de construction » seulement la ou le joueur administre
la ville (`ID_GUI_SHIPYARD_BUILD_EMPTY`). Le titre est le nom du batiment selon
son niveau : `ID_GUI_BUILDING_SHIPYARD` / `_SHIPYARD2` / `_SHIPYARD3`.

Le dialogue de ville range ses onglets sur DEUX rangees : trois a libelle
(Infos ville, Liste denrees, Equiper) puis trois onglets-ICONES de sens
d'echange, dont le libelle localise est une image
(`<img src='icon_trade_town_convoy'>`, soit dialog_trade/5-7.png, 106x17).

### Les libelles de la fiche de ville

| Champ | Cle | Exemple |
|---|---|---|
| tf_nationinfo | `ID_REPUTATION_NATION_0..3` | « %1, neutre » |
| tf_towndesc | `ID_GUI_TOWN_TYPE_00..03` | Village, Ville coloniale, Ville de Gouverneur, Vice-roi |
| tf_status_prosperity | `ID_GUI_TOWN_WEALTH_00..07` | Pauvrete…Opulence |
| tf_citizeninfo | `ID_GUI_REPUTATION_TOWN_PERCENTAGE_00..05` | « Peu de citoyens s'interessent a vous. » |

La reputation va de 0 a 100 et part a 50, qui doit se lire « neutre » : les
paliers sont des seuils (25 / 60 / 85), pas une division lineaire.
