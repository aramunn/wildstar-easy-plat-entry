require "Window"

local EasyPlatEntry = {}

local Hooks = {
  {
    addonToHook = "MarketplaceAuction",
    methodToHook = "OnToggleAuctionWindow",
    pathToWindowToHook = {
      "SellContainer",
      "CreateBuyoutInputBox",
    },
  },
}

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
        local cashWindow = addon.wndMain
        for idx, child in ipairs(hook.pathToWindowToHook) do
          cashWindow = cashWindow:FindChild(child)
        end
        cashWindow:AddEventHandler("MouseButtonDown", "EasyPlatEntryHook")
      end
      addon["EasyPlatEntryHook"] = function (wndHandler, wndControl)
        self.wndMain = Apollo.LoadForm(self.xmlDoc, "TextToMoneyForm", wndControl, self)
        self.wndMain:FindChild("EditBox"):SetFocus()
      end
    end
  end
end

local EasyPlatEntryInst = EasyPlatEntry:new()
EasyPlatEntryInst:Init()
