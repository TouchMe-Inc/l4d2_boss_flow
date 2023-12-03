#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <left4dhooks>
#include <boss_flow>
#include <colors>


public Plugin myinfo = {
    name        = "BossFlowShowPercent",
    author      = "TouchMe",
    description = "Plugin displays boss locations",
    version     = "build0004",
    url         = "https://github.com/TouchMe-Inc/l4d2_boss_flow"
}


#define TRANSLATIONS            "bf_show_percent.phrases"

#define MIN_FLOW                1


ConVar g_cvVsBossBuffer = null;


/**
 * Called before OnPluginStart.
 *
 * @param myself            Handle to the plugin.
 * @param late              Whether or not the plugin was loaded "late" (after map load).
 * @param error             Error message buffer in case load failed.
 * @param err_max           Maximum number of characters for error message buffer.
 * @return                  APLRes_Success | APLRes_SilentFailure.
 */
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    if (GetEngineVersion() != Engine_Left4Dead2)
    {
        strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
        return APLRes_SilentFailure;
    }

    return APLRes_Success;
}

public void OnPluginStart()
{
    // Load translations.
    LoadTranslations(TRANSLATIONS);

    g_cvVsBossBuffer = FindConVar("versus_boss_buffer");

    RegConsoleCmd("sm_boss", Cmd_Boss);
    RegConsoleCmd("sm_tank", Cmd_Boss);
    RegConsoleCmd("sm_witch", Cmd_Boss);
    RegConsoleCmd("sm_current", Cmd_Boss);
}

Action Cmd_Boss(int iClient, int iArgs)
{
    if (!iClient) {
        return Plugin_Continue;
    }

    CPrintToChat(iClient, "%T%T", "BRACKET_START", iClient, "TAG", iClient);

    float fBossBuffer = GetConVarFloat(g_cvVsBossBuffer) / L4D2Direct_GetMapMaxFlowDistance();

    if (IsBossSpawnAllowed(Boss_Tank))
    {
        int iTankFlow = GetBossFlow(Boss_Tank);

        if (IsMapWithStaticBossSpawn(Boss_Tank)) {
            CPrintToChat(iClient, "%T%T", "BRACKET_MIDDLE", iClient, "TANK_STATIC", iClient);
        }

        else if (iTankFlow == 0) {
            CPrintToChat(iClient, "%T%T", "BRACKET_MIDDLE", iClient, "TANK_DISABLED", iClient);
        }

        else
        {
            int iTankFlowTrigger = iTankFlow - RoundToNearest(fBossBuffer * 100.0);

            if (iTankFlowTrigger < 0) {
                iTankFlowTrigger = MIN_FLOW;
            }

            CPrintToChat(iClient, "%T%T", "BRACKET_MIDDLE", iClient, "TANK_FLOW", iClient, iTankFlowTrigger, iTankFlow);
        }
    }

    if (IsBossSpawnAllowed(Boss_Witch))
    {
        int iWitchFlow = GetBossFlow(Boss_Witch);

        if (IsMapWithStaticBossSpawn(Boss_Witch)) {
            CPrintToChat(iClient, "%T%T", "BRACKET_MIDDLE", iClient, "WITCH_STATIC", iClient);
        }

        else if (iWitchFlow == 0) {
            CPrintToChat(iClient, "%T%T", "BRACKET_MIDDLE", iClient, "WITCH_DISABLED", iClient);
        }

        else
        {
            int iWitchFlowTrigger = iWitchFlow - RoundToNearest(fBossBuffer * 100.0);

            if (iWitchFlowTrigger < 0) {
                iWitchFlowTrigger = MIN_FLOW;
            }

            CPrintToChat(iClient, "%T%T", "BRACKET_MIDDLE", iClient, "WITCH_FLOW", iClient, iWitchFlowTrigger, iWitchFlow);
        }
    }

    CPrintToChat(iClient, "%T%T", "BRACKET_END", iClient, "SURVIVOR_FLOW", iClient, GetFurthestSurvivorFlow());

    return Plugin_Handled;
}

int GetFurthestSurvivorFlow()
{
    int iFlow = RoundToCeil(100.0 * (L4D2_GetFurthestSurvivorFlow()) / L4D2Direct_GetMapMaxFlowDistance());
    return iFlow < 100 ? iFlow : 100;
}
