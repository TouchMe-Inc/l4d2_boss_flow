#if defined _boss_flow_included
 #endinput
#endif
#define _boss_flow_included

enum Boss
{
    Boss_Tank,
    Boss_Witch
}

native bool IsBossSpawnAllowed(Boss boss);

/**
 * @brief Check if the current map contains a static boss spawn.
 *
 * @return                  True on contains a static spawn, false otherwise.
 */
native bool IsMapWithStaticBossSpawn(Boss boss);

/**
 * @brief Validate the flow percentage of witch on current map.
 * @remarks Passing 0 is allowed and considered disabling.
 *
 * @param   iFlow           Flow percentage to check.
 *
 * @return					1 on avaible, 0 banned by config, -1 banned by cvar, -2 invalid flow.
 */
native int IsAvaibleBossFlow(Boss boss, int iFlow);

/**
 * @brief Set the flow of boss on current map.
 * @remarks Passing 0 is allowed and will disable flow boss.
 *
 * @param   iFlow           Flow percentage to check.
 */
native void SetBossFlow(Boss boss, int iFlow);

/**
 * @brief Get the flow of boss on current map.
 *
 * @param   iFlow           Flow percentage to check.
 */
native int GetBossFlow(Boss boss);


public SharedPlugin __pl_boss_flow =
{
    name = "boss_flow",
    file = "boss_flow.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_boss_flow_SetNTVOptional()
{
    MarkNativeAsOptional("IsBossSpawnAllowed");
    MarkNativeAsOptional("IsMapWithStaticBossSpawn");
    MarkNativeAsOptional("IsAvaibleBossFlow");
    MarkNativeAsOptional("SetBossFlow");
    MarkNativeAsOptional("GetBossFlow");
}
#endif
