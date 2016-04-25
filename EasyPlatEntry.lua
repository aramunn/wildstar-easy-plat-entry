require "Window"

local EasyPlatEntry = {}

-------------------------------------------------------------------------------
--constants
-------------------------------------------------------------------------------
--table of sets of addons we want to hook into
--  addon: name of the addon
--  [init]: set to true if method is called on load
--  method: method after which we'll add our window events
--  [container]: name of variable containing class we need
--  base: name of the variable containing the base window
--  [path]: path to the target cash window
--  [post]: function to call after setting a new amount
--  [link]: info for window to link to
--    name: name of set we want
--    levels: number of levels to go up to find it
local sets = {
  ahSellBuyout = {
    addon = "MarketplaceAuction",
    method = "Initialize",
    base = "wndMain",
    path = "CreateBuyoutInputBox",
    post = "OnCreateBuyoutInputBoxChanged",
    link = {
      name = "ahSellBid",
      levels = 2,
    },
  },
  ahSellBid = {
    addon = "MarketplaceAuction",
    method = "Initialize",
    base = "wndMain",
    path = "CreateBidInputBox",
    post = "OnCreateBidInputBoxChanged",
    link = {
      name = "ahSellBuyout",
      levels = 2,
    },
  },
  {
    addon = "MarketplaceAuction",
    method = "Initialize",
    base = "wndMain",
    path = "BottomBidPrice",
    post = "OnBidPriceAmountChanged",
  },
  {
    addon = "MarketplaceAuction",
    method = "Initialize",
    base = "wndMain",
    path = "FilterOptionsBuyoutCash",
    post = "OnFilterEditBoxChanged",
  },
  {
    addon = "MarketplaceCommodity",
    method = "OnListInputPriceMouseDown",
    post = "OnListInputPriceAmountChanged",
  },
  {
    addon = "MarketplaceCREDD",
    method = "Initialize",
    base = "tWindowMap.Main",
    path = "ActLaterPrice",
    post = "OnCashInputChanged",
  },
  {
    addon = "GuildBank",
    method = "Initialize",
    base = "tWndRefs.wndMain",
    path = "GuildCashInteractEditCashWindow",
    post = "OnGuildCashInteractEditCashWindow",
  },
  -- {
    -- addon = "GuildBank",
    -- method = "GuildInitialize",
    -- base = "tWndRefs.wndMain",
    -- path = "PermissionsMoneyCashWindow",
    -- post = "OnPermissionsMoneyCashWindow",
  -- },
  -- {
    -- addon = "GuildBank",
    -- method = "GuildInitialize",
    -- base = "tWndRefs.wndMain",
    -- path = "PermissionsRepairCashWindow",
    -- post = "OnPermissionsRepairCashWindow",
  -- },
  {
    addon = "Mail",
    method = "ComposeMail",
    container = "luaComposeMail",
    base = "wndMain",
    path = "CashEntry:CashWindow",
    post = "OnCashAmountChanged",
  },
  {
    addon = "Trading",
    init = true,
    method = "OnDocumentReady",
    base = "wndTradeForm",
    path = "YourCash",
    post = "OnCashAmountChanged",
  },
  --@do-not-package@
  {
    addon = "MarketScanner",
    method = "OnListInputPriceMouseDown",
    post = "OnListInputPriceAmountChanged",
  },
  --@end-do-not-package@
}

--what to call the methods we add to other addons
local eventFunctionPrefix = "EasyPlatEntryEvent"

local descriptions = {
  ahBidBuyoutLink = "AH Link Bid/Buyout Price",
  ahUseLastBid    = "AH Auto Fill Last Bid Price",
  ahUseLastBuyout = "AH Auto Fill Last Buyout Price",
}

local tSaveDefault = {
  ahBidBuyoutLink = {
    enable = false,
    percent = 75,
  },
  ahUseLastBid = {
    enable = false,
  },
  ahUseLastBuyout = {
    enable = false,
  },
}

local settingUpdated = {
  ahBidBuyoutLink = function(data)
    local percent = (data.enable and data.percent) or nil
    sets.ahSellBuyout.link.percent  = percent and percent/100
    -- sets.ahSellBid.link.percent     = percent and 100/percent
  end,
  ahUseLastBid = function(data)
    sets.ahSellBid.last = { enable = data.enable }
  end,
  ahUseLastBuyout = function(data)
    sets.ahSellBuyout.last = { enable = data.enable }
  end,
}

local optionSave = {
  enable = function(option)
    return option:FindChild("Enable"):IsChecked()
  end,
  percent = function(option)
    return tonumber(option:FindChild("Percent:EditBox"):GetText())
  end,
}

local optionLoad = {
  description = function(option, description)
    local window = option:FindChild("Description")
    window:SetText(description)
    return window
  end,
  enable = function(option, enabled)
    local button = option:FindChild("Enable")
    button:SetCheck(enabled)
    button:SetText(enabled and "Enabled" or "Disabled")
    return button
  end,
  percent = function(option, percent)
    local window = option:FindChild("Percent")
    window:FindChild("EditBox"):SetText(tostring(percent))
    return window
  end,
}

-------------------------------------------------------------------------------
--using a cash amount, build a string in proper format
-------------------------------------------------------------------------------
function EasyPlatEntry:ConvertAmountToString(amt)
  local curAmtStr = ""
  local denominations = { "c", "s", "g", "p" }
  for idx, denomination in ipairs(denominations) do
    --extract denomination value from amount
    local value = amt
    if idx < #denominations then value = value % 100 end
    --add value to string if not zero
    if value > 0 then
      --add space if more than one value in this string
      if curAmtStr ~= "" then
        curAmtStr = " "..curAmtStr
      end
      --add value and denomination character to front of string
      curAmtStr = value..denomination..curAmtStr
    end
    --adjust amount
    amt = (amt - value) / 100
  end
  return curAmtStr
end

-------------------------------------------------------------------------------
--parse a (hopefully) formatted string
-------------------------------------------------------------------------------
function EasyPlatEntry:ConvertStringToAmount(str)
  local strToParse = string.lower(str)
  local total = 0
  local strToCompare = ""
  local denominations = { "p", "g", "s", "c" }
  for idx, denomination in ipairs(denominations) do
    --get a number followed by a denomination character
    local value, remaining = string.match(strToParse, "^%s*(%d+)%s*"..denomination.."(.*)$")
    if value ~= nil then
      --add appropriate amount to total
      total = total + math.floor(tonumber(value) * math.pow(100, #denominations - idx))
      --update our strings
      strToParse = remaining
      strToCompare = strToCompare..value..denomination
    end
  end
  --check if the string we made matches the user's input
  local matches = strToCompare == string.lower(string.gsub(str, '%s', ""))
  return total, matches
end

-------------------------------------------------------------------------------
--handle linked windows
-------------------------------------------------------------------------------
function EasyPlatEntry:HandleLink(data, addon, window, amount, tab)
  --grab set data for window we want to link to
  local set = sets[data.name]
  --go up from current window then find our target
  local link = window
  for i=1,data.levels do link = link:GetParent() end
  link = link:FindChild(set.path)
  --quit if we didn't find target window
  if not link then return end
  --update linked window with relative value
  if data.percent then
    local amount = math.floor(amount*data.percent + .5) --round
    self:UpdateAmount(link, set, amount)
  end
  --pretend we clicked the linked window if tab was used
  if tab then self:MouseButtonDownEvent(link, set) end
end

-------------------------------------------------------------------------------
--update cash window
-------------------------------------------------------------------------------
function EasyPlatEntry:UpdateAmount(cashWindow, set, amount, tab)
  --don't do anything if we already updated this window
  if self.windowsUpdated[set.path or "no path"] then return
  else self.windowsUpdated[set.path or "no path"] = true end
  --get the old amount
  local monOldAmount = cashWindow:GetAmount()
  --set the new amount
  cashWindow:SetAmount(amount)
  if set.last and set.last.enable then set.last.amount = amount end
  --get the new amount
  local monNewAmount = cashWindow:GetAmount()
  --call post method if needed
  if set and set.post then
    local addon = Apollo.GetAddon(set.addon)
    if set.container then addon = addon[set.container] end
    addon[set.post](addon, cashWindow, cashWindow, monNewAmount, monOldAmount)
    --handle links
    if set.link then self:HandleLink(set.link, addon, cashWindow, amount, tab) end
  end
end

-------------------------------------------------------------------------------
--create an error display
-------------------------------------------------------------------------------
function EasyPlatEntry:UpdateError(cashWindow, editBox)
  --clean up old errors if they exist
  self:OnPixieTimer()
  --decide where to put the error
  local errorOffsets
  if self.wndMain:IsVisible() then
    errorWindow = self.wndMain
    errorOffsets = {5,0,-5,2}
    editBox:SetFocus()
  else
    errorWindow = cashWindow
    errorOffsets = {0,-5,0,5}
  end
  --add the error display and set a timer
  errorPixie = errorWindow:AddPixie({
    strSprite = "CRB_NameplateSprites:sprNp_VulnerableBarFlash",
    loc = { fPoints = {0,0,1,1}, nOffsets = errorOffsets },
    cr = "AddonError",
  })
  self.timer = ApolloTimer.Create(0.5, false, "OnPixieTimer", self)
end

-------------------------------------------------------------------------------
--read window status and update as needed
-------------------------------------------------------------------------------
function EasyPlatEntry:UpdateWindow(tab)
  --reset flags
  self.windowsUpdated = {}
  --ensure our window is up
  if not self.wndMain or not self.wndMain:IsValid() then return end
  --grab the cash window we're attached to
  local cashWindow = self.wndMain:GetParent()
  --attempt to get value from string
  local editBox = self.wndMain:FindChild("EditBox")
  local amount, good = self:ConvertStringToAmount(editBox:GetText())
  if good then
    local set = editBox:GetData()
    self:Destroy()
    self:UpdateAmount(cashWindow, set, amount, tab)
  else
    self:UpdateError(cashWindow, editBox)
  end
end

-------------------------------------------------------------------------------
--timer functions
-------------------------------------------------------------------------------
function EasyPlatEntry:OnPixieTimer()
  if errorWindow and errorWindow:IsValid() then
    errorWindow:DestroyPixie(errorPixie)
  end
  errorWindow = nil
end

-------------------------------------------------------------------------------
--when user hits escape in the edit box
-------------------------------------------------------------------------------
function EasyPlatEntry:OnEditBoxEscape()
  self:Destroy()
end

-------------------------------------------------------------------------------
--when user clicks off of the pop-up window
-------------------------------------------------------------------------------
function EasyPlatEntry:OnWindowClosed()
  self:UpdateWindow()
  self:Destroy()
end

-------------------------------------------------------------------------------
--when user hits enter in the edit box
-------------------------------------------------------------------------------
function EasyPlatEntry:OnEditBoxReturn(wndHandler, wndControl, strText)
  self:UpdateWindow()
end

-------------------------------------------------------------------------------
--when user hits tab in the edit box
-------------------------------------------------------------------------------
function EasyPlatEntry:OnEditBoxTab(wndHandler, wndControl, strText)
  self:UpdateWindow(true)
end

-------------------------------------------------------------------------------
--destroy our main window
-------------------------------------------------------------------------------
function EasyPlatEntry:Destroy()
  if self.wndMain and self.wndMain:IsValid() then
    self.wndMain:Destroy()
    self.wndMain = nil
  end
end

-------------------------------------------------------------------------------
--event called by hooked cash window
-------------------------------------------------------------------------------
function EasyPlatEntry:MouseButtonDownEvent(cashWindow, set)
  --update and remove a previous window
  self:UpdateWindow()
  self:Destroy()
  --load our pop-up window
  self.wndMain = Apollo.LoadForm(self.xmlDoc, "EasyPlatEntryForm", cashWindow, self)
  local editBox = self.wndMain:FindChild("EditBox")
  --add data to edit box for later
  editBox:SetData(set)
  --set current value and focus on edit box
  local amount = cashWindow:GetAmount()
  if type(amount) == "userdata" then amount = amount:GetAmount() end
  if set.last and set.last.enable and set.last.amount then
    amount = set.last.amount
  end
  editBox:SetText(self:ConvertAmountToString(amount))
  editBox:SetFocus()
end

-------------------------------------------------------------------------------
--add our event to target window
-------------------------------------------------------------------------------
function EasyPlatEntry:AddWindowEvent(set, addon, window)
    local addon = addon
    --check if container present
    if set.container then
      addon = addon[set.container]
      if addon["EasyPlatEntryFlag"] then return end
      addon["EasyPlatEntryFlag"] = true
    end
    if set.path then
      --we need to add an event handler to a window and the addon
      local eventFunctionName = eventFunctionPrefix
      if set.post then eventFunctionName = eventFunctionName.."With"..set.post end
      local wndBase = addon
      for base in string.gmatch(set.base, '%w+') do
        wndBase = wndBase[base]
      end
      local cashWindow = wndBase:FindChild(set.path)
      if not cashWindow then return end
      cashWindow:AddEventHandler("MouseButtonDown", eventFunctionName)
      addon[eventFunctionName] = function(ref, wndHandler, wndControl) self:MouseButtonDownEvent(wndHandler, set) end
    else
      --we only need to add to the existing handler
      self:MouseButtonDownEvent(window, set)
    end
end

-------------------------------------------------------------------------------
--set processing
-------------------------------------------------------------------------------
function EasyPlatEntry:ProcessSet(set, addon)
  if set.init and addon[set.base] then
    self:AddWindowEvent(set, addon)
  else
    --add extra code to a function in addon
    local method = addon[set.method]
    addon[set.method] = function (ref, wndHandler, wndControl, ...)
      method(ref, wndHandler, wndControl, ...)
      self:AddWindowEvent(set, addon, wndHandler)
    end
  end
end

function EasyPlatEntry:ProcessSets()
  --iterate through sets
  for idx, set in pairs(sets) do
    --ensure addon is running
    local addon = Apollo.GetAddon(set.addon)
    if addon then
      self:ProcessSet(set, addon)
    end
  end
end

-------------------------------------------------------------------------------
--options
-------------------------------------------------------------------------------
function EasyPlatEntry:OnOK()
  for idx, option in pairs(self.wndOptions:FindChild("List"):GetChildren()) do
    local name = option:GetData()
    local data = self.tSave[name]
    for key in pairs(data) do
      data[key] = optionSave[key](option)
    end
  end
  self.wndOptions:Destroy()
  self:SettingsUpdated()
end

function EasyPlatEntry:OnCancel()
  self.wndOptions:Destroy()
end

function EasyPlatEntry:OnEnableDisableOption(wndHandler, wndControl)
  wndControl:SetText(wndControl:IsChecked() and "Enabled" or "Disabled")
end

function EasyPlatEntry:OnPercentChanged(wndHandler, wndControl, strText)
  local number = tonumber(strText)
  local valid = tostring(number) == strText and number >= 0 and number <= 100
  wndControl:GetParent():SetData(not valid)
  wndControl:SetTextColor(valid and "UI_TextHoloBody" or "AddonError")
  self:ValidateOptions()
end

function EasyPlatEntry:ValidateOptions()
  local valid = true
  for idx, option in pairs(self.wndOptions:FindChild("List"):GetChildren()) do
    local invalid = option:FindChild("Percent"):GetData()
    option:FindChild("Description"):SetTextColor(invalid and "AddonError" or "UI_TextHoloBody")
    if invalid then valid = false end
  end
  self.wndOptions:FindChild("OkButton"):Enable(valid)
end

function EasyPlatEntry:LoadOption(list, data)
  local option = Apollo.LoadForm(self.xmlDoc, "EasyPlatEntryOption", list, self)
  for name, value in pairs(data) do
    optionLoad[name](option, value):Show(true)
  end
  return option
end

function EasyPlatEntry:LoadOptionsWindow()
  if self.wndOptions and self.wndOptions:IsValid() then self.wndOptions:Destroy() end
  self.wndOptions = Apollo.LoadForm(self.xmlDoc, "EasyPlatEntryOptions", nil, self)
  local list = self.wndOptions:FindChild("List")
  for name, data in pairs(self.tSave) do
    local option = self:LoadOption(list, data)
    optionLoad.description(option, descriptions[name])
    option:SetData(name)
  end
  list:ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop)
end

function EasyPlatEntry:SettingsUpdated()
  for name, data in pairs(self.tSave) do
    settingUpdated[name](data)
  end
end

function EasyPlatEntry:OnSave(eLevel)
  if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then return nil end
  return self.tSave
end

function EasyPlatEntry:OnRestore(eLevel, tSave)
  self.tSave = tSaveDefault
  --load user settings, removing old ones
  for name, data in pairs(tSave) do
    local setting = self.tSave[name]
    for key, value in pairs(data) do
      if setting[key] ~= nil then setting[key] = value end
    end
  end
  self:SettingsUpdated()
end

function EasyPlatEntry:OnInterfaceMenuLoaded()
  local tData = {"EasyPlatEntryInterfaceMenu", "", "CRB_CurrencySprites:sprCashPlatinum"}
  Event_FireGenericEvent("InterfaceMenuList_NewAddOn", "EasyPlatEntry", tData)
end

-------------------------------------------------------------------------------
--required addon functions
-------------------------------------------------------------------------------
function EasyPlatEntry:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function EasyPlatEntry:Init()
  self.tSave = tSaveDefault
  self:SettingsUpdated()
  Apollo.RegisterAddon(self)
end

function EasyPlatEntry:OnLoad()
  self.xmlDoc = XmlDoc.CreateFromFile("EasyPlatEntry.xml")
  self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function EasyPlatEntry:OnDocumentReady()
  --make sure xml is loaded
  if self.xmlDoc == nil then return end
  if not self.xmlDoc:IsLoaded() then return end
  --process everything
  self:ProcessSets()
  --register what we need
  Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuLoaded", self)
  Apollo.RegisterEventHandler("EasyPlatEntryInterfaceMenu", "LoadOptionsWindow", self)
  Apollo.RegisterSlashCommand("easyplatentry", "LoadOptionsWindow", self)
  Apollo.RegisterSlashCommand("epe", "LoadOptionsWindow", self)
end

-------------------------------------------------------------------------------
--set up addon
-------------------------------------------------------------------------------
local errorPixie, errorWindow
local EasyPlatEntryInst = EasyPlatEntry:new()
EasyPlatEntryInst:Init()
