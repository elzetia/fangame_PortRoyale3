# PR3 — structure des écrans (UI Flash/Iggy)

Généré par `outils/swf_ui.py` (lit ta copie locale). Pour chaque écran `.swf`, on
sort la SCÈNE (taille), le **catalogue des composants** (SymbolClass : les widgets
réutilisables et leur hiérarchie) et les **placements nommés** (instances + classe +
position). Aucune image extraite (droits) : c'est la STRUCTURE pour recréer les
écrans dans Godot.

Note : les positions des éléments à transformation de couleur (CXFORM) ont un léger
bruit de parse ; le catalogue et la hiérarchie, eux, sont exacts.

================================================================
# ingame_radial_town.swf  sc�ne 2880x2880 px
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
  19 sprites, 1 placements racine
  68 placements nommes :
    mc_bg                            @(0,0) x1 <char2>
    RAD_LEFT                         @(57,262) x1 <char6>
    RAD_DOWNLEFT                     @(117,409) x1 <char6>
    RAD_DOWN                         @(264,470) x1 <char6>
    RAD_DOWNRIGHT                    @(411,409) x1 <char6>
    RAD_RIGHT                        @(472,262) x1 <char6>
    RAD_UPLEFT                       @(117,116) x1 <char6>
    RAD_UPRIGHT                      @(411,116) x1 <char6>
    townstate                        @(63,25) x1 <ingame_radial_town_fla.Icon_Towns_Big_9>
    tton.Visual_IconButton_Events_NoBg @(-2690702,-672075) x1 <->
    tton.Visual_IconButton_Events_NoBg @(-2690702,-672075) x1 <->
    tton.Visual_IconButton_Events_NoBg @(-2690702,-672075) x1 <->
    tton.Visual_IconButton_Goods_NoBg @(-2690702,-672075) x1 <->
    tton.Visual_IconButton_Goods_NoBg @(-2690702,-672075) x1 <->
    tton.Visual_IconButton_Goods_NoBg @(-2690702,-672075) x1 <->
    tton.Visual_IconButton_Goods_NoBg @(-2690702,-672075) x1 <->
    tton.Visual_IconButton_Goods_NoBg @(-2690702,-672075) x1 <->
    xtfield.Visual_Textfeld_16       @(-2690702,-672060) x1 <->
    xtfield.Visual_Textfeld_16       @(-2690702,-672060) x1 <->
    xtfield.Visual_Textfeld_16_Shadow @(-2690702,-672060) x1 <->
    tton.Visual_IconButton_habitants @(-2690702,-672075) x1 <->
    tton.Visual_IconButton_ThumbsUp  @(-2690702,-672075) x1 <->
    ual_NationFlag_Small             @(23589,21010) x1 <->
    tton.Visual_IconButton_Towninfo  @(-2690702,-672075) x1 <->
    gr_goods                         @(-65,59) x1 <ingame_radial_town_fla.Group_ProdGoods_11>
    imatedelement.Visual_AniElement_Reputationmarker @(-2690702,-672076) x1 <->
    xtfield.Visual_Textfeld_20_Shadow @(-2690702,-672060) x1 <->
    tton.Visual_IconButton_Ship_Regular @(-2690702,-672075) x1 <->
    tton.Visual_IconButton_Events_Building @(-2690702,-672075) x1 <->
    tton.Visual_IconButton_Events_Building @(-2690702,-672075) x1 <->
    tton.Visual_IconButton_Events_Building @(-2690702,-672075) x1 <->
    xtfield.Visual_Textfeld_20_Shadow @(-2690702,-672060) x1 <->
    xtfield.Visual_Textfeld_20_Shadow @(-2690702,-672060) x1 <->
    icon_ships                       @(13,0) x1 <char39>
    icon_convoys                     @(1,62) x1 <char40>
    tton.Visual_IconButton_Events_Building @(-2690702,-672075) x1 <->
    tton.Visual_IconButton_Events_Building @(-2690702,-672075) x1 <->
    tton.Visual_IconButton_Events_Building @(-2690702,-672075) x1 <->
    tton.Visual_IconButton_Events_Building @(-2690702,-672075) x1 <->
    tton.Visual_IconButton_Events_Building @(-2690702,-672075) x1 <->
    tton.Visual_IconButton_Events_Building @(-2690702,-672075) x1 <->
    tton.Visual_IconButton_Events_Building @(-2690702,-672075) x1 <->
    tton.Visual_IconButton_Events_Building @(-2690702,-672075) x1 <->

================================================================
# dialog_convoy_town_pc.swf  sc�ne 2880x2880 px
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
  31 sprites, 1 placements racine
  237 placements nommes :
    rollbar.Visual_Scrollbar_List    @(-2690702,-672061) x1 <->
    tton.Visual_ListButton_ShipListDetails @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_ShipListDetails @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_ShipListDetails @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_ShipListDetails @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_ShipListDetails @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_ShipListDetails @(-2690702,-672075) x1 <->
    tton.Visual_IconButton_Town_Storage @(-2690702,-672075) x1 <->
    tton.Visual_IconButton_Cannon    @(-2690702,-672075) x1 <->
    tton.Visual_IconButton_Heart     @(-2690702,-672075) x1 <->
    sort_dir                         @(358,4) x1 <dialog_convoy_town_pc_fla.Icons_Arrow_UpDown_8>
    tton.Visual_Button_Empty         @(-2690702,-672075) x1 <->
    li_ships                         @(0,90) x1 <components.list.Visual_List_Ships>
    sortbar                          @(0,68) x1 <components.animatedelement.Visual_AniElement_Sortbar_Ship>
    rollbar.Visual_Scrollbar_List    @(-2690702,-672061) x1 <->
    tton.Visual_ListButton_TownListDetails @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_TownListDetails @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_TownListDetails @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_TownListDetails @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_TownListDetails @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_TownListDetails @(-2690702,-672075) x1 <->
    tton.Visual_IconButton_ThumbsUp  @(-2690702,-672075) x1 <->

================================================================
# hud_pc.swf  sc�ne 2880x2880 px
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

================================================================
# dialog_route_details.swf  sc�ne 2880x2880 px
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
  20 sprites, 2 placements racine
  98 placements nommes :
    xtfield.Visual_Textfeld_16       @(-2690702,-672060) x1 <->
    tton.Visual_Button_Right         @(-2690702,-672075) x1 <->
    tton.Visual_Button_Left          @(-2690702,-672075) x1 <->
    button_set                       @(0,0) x1 <dialog_route_details_fla.Buttonset_Select_Mode_18>
    rollbar.Visual_Scrollbar_List    @(-2690702,-672061) x1 <->
    tton.Visual_IconButton_Goods     @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_Lock      @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_Lock      @(-2690702,-672075) x1 <->
    tton.Visual_IconButton_Goods     @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_Lock      @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_Lock      @(-2690702,-672075) x1 <->
    tton.Visual_IconButton_Goods     @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_Lock      @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_Lock      @(-2690702,-672075) x1 <->
    tton.Visual_IconButton_Goods     @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_Lock      @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_Lock      @(-2690702,-672075) x1 <->
    tton.Visual_IconButton_Goods     @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_Lock      @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_Lock      @(-2690702,-672075) x1 <->
    tton.Visual_IconButton_Goods     @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_Lock      @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_Lock      @(-2690702,-672075) x1 <->
    tton.Visual_IconButton_Goods     @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_Lock      @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_Lock      @(-2690702,-672075) x1 <->
    tton.Visual_IconButton_Goods     @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_Lock      @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_Lock      @(-2690702,-672075) x1 <->
    tton.Visual_IconButton_Goods     @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_Lock      @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_Lock      @(-2690702,-672075) x1 <->
    tton.Visual_IconButton_Goods     @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_Lock      @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_Lock      @(-2690702,-672075) x1 <->
    tton.Visual_IconButton_Unlock_Small @(-2690702,-672075) x1 <->
    tton.Visual_IconButton_NoAnchor_Small @(-2690702,-672075) x1 <->

================================================================
# dialog_harbourmaster.swf  sc�ne 2880x2880 px
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
  17 sprites, 1 placements racine
  78 placements nommes :
    xtbutton.Visual_TextButton_Tab   @(-2690702,-672060) x1 <->
    xtbutton.Visual_TextButton_Tab   @(-2690702,-672060) x1 <->
    xtbutton.Visual_TextButton_Tab   @(-2690702,-672060) x1 <->
    xtbutton.Visual_TextButton_Tab   @(-2690702,-672060) x1 <->
    xtbutton.Visual_TextButton_Tab   @(-2690702,-672060) x1 <->
    xtbutton.Visual_TextButton_Tab   @(-2690702,-672060) x1 <->
    mc_mask                          @(14,3) x12.344 <char3>
    xtbutton.Visual_TextButton_Tab   @(-2690702,-672060) x1 <->
    xtbutton.Visual_TextButton_Tab   @(-2690702,-672060) x1 <->
    xtbutton.Visual_TextButton_Tab   @(-2690702,-672060) x1 <->
    xtbutton.Visual_TextButton_Tab   @(-2690702,-672060) x1 <->
    xtbutton.Visual_TextButton_Tab   @(-2690702,-672060) x1 <->
    xtbutton.Visual_TextButton_Tab   @(-2690702,-672060) x1 <->
    xtfield.Visual_Textfeld_16       @(-2690702,-672060) x1 <->
    xtfield.Visual_Textfeld_16       @(-2690702,-672060) x1 <->
    xtfield.Visual_Textfeld_16       @(-2690702,-672060) x1 <->
    xtfield.Visual_Textfeld_16       @(-2690702,-672060) x1 <->
    tton.Visual_ListButton_Equipment_Harbourmaster @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_Equipment_Harbourmaster @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_Equipment_Harbourmaster @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_Equipment_Harbourmaster @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_Equipment_Harbourmaster @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_Equipment_Harbourmaster @(-2690702,-672075) x1 <->
    xtfield.Visual_Textfeld_Subheadline @(-2690702,-672060) x1 <->
    tton.Visual_Button_Infotext      @(-2690702,-672075) x1 <->
    ual_Equipment_Overlay_Harbourmaster @(23589,21010) x1 <->
    li_equipment                     @(-1,92) x1 <components.list.Visual_List_Equipment>
    icn_tt_0                         @(0,35) x1 <components.focuselement.Visual_Icon_Captain>
    xtfield.Visual_Textfeld_16       @(-2690702,-672060) x1 <->
    xtfield.Visual_Textfeld_16       @(-2690702,-672060) x1 <->
    xtfield.Visual_Textfeld_Subheadline @(-2690702,-672060) x1 <->
    tton.Visual_Iconbutton_Cycle     @(-2690702,-672075) x1 <->
    tton.Visual_Button_Infotext      @(-2690702,-672075) x1 <->
    xtfield.Visual_Textfeld_16       @(-2690702,-672060) x1 <->
    xtfield.Visual_Textfeld_16       @(-2690702,-672060) x1 <->
    rollbar.Visual_Scrollbar_List    @(-2690702,-672061) x1 <->
    tton.Visual_ListButton_Bships    @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_Bships    @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_Bships    @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_Bships    @(-2690702,-672075) x1 <->
    tton.Visual_ListButton_Bships    @(-2690702,-672075) x1 <->

