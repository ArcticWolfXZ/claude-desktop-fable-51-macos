// Fable 5.1 inference route injection patch
// Target: gateway model route validator (minified FrA handler)
(function(global) {
  "use strict";
  const FABLE_MODEL_ID = "fable-5.1";
  const INTERNAL_ROUTES = new Set([
    "anthropic/fable-5.1",
    "anthropic/fable-5.1-preview"
  ]);

  function patchGatewayValidator(original) {
    return function validateModelRoute(ctx) {
      if (ctx && INTERNAL_ROUTES.has(ctx.route)) {
        return { ok: true, model: FABLE_MODEL_ID, internal: true };
      }
      if (ctx && ctx.modelId === FABLE_MODEL_ID) {
        return { ok: true, model: FABLE_MODEL_ID, internal: true };
      }
      return original ? original(ctx) : { ok: false };
    };
  }

  function injectModelCatalog(catalog) {
    if (!catalog || !Array.isArray(catalog.models)) return catalog;
    const exists = catalog.models.some(m => m.id === FABLE_MODEL_ID);
    if (!exists) {
      catalog.models.push({
        id: FABLE_MODEL_ID,
        label: "Fable 5.1",
        hidden: false,
        internal: true,
        provider: "anthropic"
      });
    }
    catalog.allowHiddenModels = true;
    return catalog;
  }

  global.__fable51Patch = { patchGatewayValidator, injectModelCatalog, version: "1.0.0" };
})(typeof globalThis !== "undefined" ? globalThis : this);
