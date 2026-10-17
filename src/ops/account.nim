import std/json
import ../net/client
import ../support/log

proc bootstrap*(session: Session): tuple[user: JsonNode, settings: JsonNode] =
  let profile = userJson(session.initData)
  let body = %*{
    "userId": session.userId,
    "username": valueOf(profile, "username", "user_" & session.userId),
    "firstName": valueOf(profile, "first_name"),
    "lastName": valueOf(profile, "last_name"),
    "photoUrl": (if profile.hasKey("photo_url"): profile["photo_url"] else: newJNull()),
    "isPremium": boolOf(profile, "is_premium", false),
    "refereeId": newJNull()
  }
  let (code, node) = session.callJson("POST", "/api/users/init", body)
  if code != 200:
    return (newJObject(), newJObject())
  result = (node{"user"}, node{"settings"})

proc refresh*(session: Session): JsonNode =
  let (code, node) = session.callJson("GET", "/api/users/" & session.userId)
  if code == 200: node else: newJObject()

proc balanceOf*(user: JsonNode): float =
  floatOf(user, "balance", 0.0)

proc referralCount*(user: JsonNode): int =
  intOf(user, "referralCount", 0)

proc runCheckin*(session: Session) =
  let (code, node) = session.callJson("POST", "/api/checkin", %*{"userId": session.userId})
  if code == 200 and boolOf(node, "success", false):
    green("Daily check in was credited with " & $intOf(node, "reward", 0) & " coins on this account")
  elif code == 400:
    yellow("Daily check in was already claimed for today on this account")
  else:
    yellow("Daily check in is not available right now on this account")

proc runInviteTasks*(session: Session, user: JsonNode) =
  let (code, node) = session.callJson("GET", "/api/referrals/invite-tasks")
  if code != 200 or node.kind != JArray:
    return
  let invites = referralCount(user)
  var index = 0
  var claimed = 0
  for entry in node:
    let required = intOf(entry, "requiredInvites", 0)
    if invites >= required:
      let (claimCode, claimNode) = session.callJson("POST",
        "/api/referrals/invite-tasks/claim",
        %*{"userId": session.userId, "taskIndex": index})
      if claimCode == 200 and boolOf(claimNode, "success", false):
        inc claimed
        green("Invite task " & cleanText(valueOf(entry, "title"), "task") & " was claimed for " & $intOf(entry, "reward", 0) & " coins on this account")
    inc index
  if claimed == 0 and invites > 0:
    yellow("No invite task is claimable yet because the invite count is low")
