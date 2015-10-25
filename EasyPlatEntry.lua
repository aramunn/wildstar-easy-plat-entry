require "Window"

local EasyPlatEntry = {}

local Hooks = {
  {
    addonToHook = "MarketplaceAuction",
    methodToHook = "OnToggleAuctionWindow",
    pathToWindowsToHook = {
      {
        "SellContainer",
        "CreateBuyoutInputBox",
      },
      {
        "SellContainer",
        "CreateBidInputBox",
      },
      {
        "BuyContainer",
        "BottomBidPrice",
      },
      {
        "AdvancedOptionsContainer",
        "FilterOptionsBuyoutCash",
      },
    },
  },
}

local errorPixie

function EasyPlatEntry:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function EasyPlatEntry:Init()
  Apollo.RegisterAddon(self)
end

function EasyPlatEntry:OnLoad()
  self.xmlDoc = XmlDoc.CreateFromFile("EasyPlatEntry.xml")
  self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function EasyPlatEntry:OnDocumentReady()
  if self.xmlDoc == nil then return end
  if not self.xmlDoc:IsLoaded() then return end
  for idx, hook in ipairs(Hooks) do
    local addon = Apollo.GetAddon(hook.addonToHook)
    if addon ~= nil then
      local method = addon[hook.methodToHook]
      addon[hook.methodToHook] = function (...)
        method(...)
        for idx, path in ipairs(hook.pathToWindowsToHook) do
          local cashWindow = addon.wndMain
          for idx, child in ipairs(path) do
            cashWindow = cashWindow:FindChild(child)
          end
          cashWindow:AddEventHandler("MouseButtonDown", "EasyPlatEntryHook")
        end
      end
      addon["EasyPlatEntryHook"] = function (wndHandler, wndControl)
        if self.wndMain and self.wndMain:IsValid() then self.wndMain:Destroy() end
        self.wndMain = Apollo.LoadForm(self.xmlDoc, "TextToMoneyForm", wndControl, self)
        self.wndMain:FindChild("EditBox"):SetFocus()
      end
    end
  end
end

function EasyPlatEntry:OnEditBoxReturn(wndHandler, wndControl, strText)
  local cashWindow = self.wndMain:GetParent()
  local strToParse = string.lower(strText)
  local denominations = { "p", "g", "s", "c" }
  local total = 0
  local strToCompare = ""
  for idx, denomination in ipairs(denominations) do
    local value, remaining = string.match(strToParse, "^%s*(%d+)%s*"..denomination.."(.*)$")
    if value ~= nil then
      total = total + math.floor(tonumber(value) * math.pow(100, #denominations - idx))
      strToParse = remaining
      strToCompare = strToCompare..value..denomination
    end
  end
  if strToCompare == string.lower(string.gsub(strText, '%s', "")) then
    cashWindow:SetAmount(total)
    self.wndMain:Destroy()
    self.wndMain = nil
  else
    errorPixie = self.wndMain:AddPixie({
      strSprite = "CRB_NameplateSprites:sprNp_VulnerableBarFlash",
      loc = {
        fPoints = {0,0,1,1},
        nOffsets = {5,0,-5,2}
      },
      cr = "AddonError"
    })
    self.timer = ApolloTimer.Create(0.5, false, "OnPixieTimer", self)
  end
end

function EasyPlatEntry:OnPixieTimer()
  self.wndMain:DestroyPixie(errorPixie)
end

local EasyPlatEntryInst = EasyPlatEntry:new()
EasyPlatEntryInst:Init()
