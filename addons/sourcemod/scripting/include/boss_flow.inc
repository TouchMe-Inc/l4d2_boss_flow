#if defined _boss_flow_included
 #endinput
#endif
#define _boss_flow_included


native bool IsTankSpawnAllow();

native bool IsWitchSpawnAllow();

/**
 * @brief Check if the current map contains a static witch spawn.
 * @remarks Map string will be converted to lowercase internally.
 *
 * @return					True on contains a static spawn, false otherwise.
 */
native bool IsStaticWitchMap();

/**
 * @brief Check if the current map contains a static tank spawn.
 * @remarks Map string will be converted to lowercase internally.
 *
 * @return					True on contains a static spawn, false otherwise.
 */
native bool IsStaticTankMap();

/**
 * @brief Validate the flow percentage of tank on current map.
 * @remarks Passing 0 is allowed and considered disabling.
 *
 * @param	iPercent		Flow percentage to check.
 *
 * @return					True on valid, false otherwise.
 */
native bool IsValidTankFlowPercent(int iPercent);

/**
 * @brief Validate the flow percentage of witch on current map.
 * @remarks Passing 0 is allowed and considered disabling.
 *
 * @param	iPercent		Flow percentage to check.
 *
 * @return					True on valid, false otherwise.
 */
native bool IsValidWitchFlowPercent(int iPercent);

/**
 * @brief Set the flow percentage of tank on current map.
 * @remarks Passing 0 is allowed and will disable flow tank.
 *
 * @param	iPercent	    Flow percentage to check.
 */
native void SetTankFlowPercent(int iPercent);

native int GetTankFlowPercent();

/**
 * @brief Set the flow percentage of witch on current map.
 * @remarks Passing 0 is allowed and will disable flow witch.
 *
 * @param	iPercent		Flow percentage to check.
 */
native void SetWitchFlowPercent(int iPercent);

native int GetWitchFlowPercent();


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
	MarkNativeAsOptional("IsTankSpawnAllow");
	MarkNativeAsOptional("IsWitchSpawnAllow");
	MarkNativeAsOptional("IsStaticWitchMap");
	MarkNativeAsOptional("IsStaticTankMap");
	MarkNativeAsOptional("IsValidTankFlowPercent");
	MarkNativeAsOptional("IsValidWitchFlowPercent");
	MarkNativeAsOptional("SetTankFlowPercent");
	MarkNativeAsOptional("GetTankFlowPercent");
	MarkNativeAsOptional("SetWitchFlowPercent");
	MarkNativeAsOptional("GetWitchFlowPercent");
}
#endif