import { getSystemProviders } from '@shared/providers'
import type { ProviderModelInfo } from '@shared/types'
import { identity, omitBy } from 'lodash'
// [CUSTOM-BEGIN] CUSTOM-20260903-005 - settings access via getSettingsSnapshot (safe against action loss)
import { getSettingsSnapshot, settingsStore } from '@/stores/settingsStore'
// [CUSTOM-END] CUSTOM-20260903-005

function updateModelInfo(localModel: ProviderModelInfo, newModelInfo: ProviderModelInfo) {
  return {
    ...newModelInfo,
    ...omitBy(localModel, identity),
  }
}

function updateLocalModels(providerId: string, latestModels: ProviderModelInfo[]) {
  const settings = getSettingsSnapshot()

  if (!settings) return

  const localModels = settings.providers?.[providerId]?.models
  if (!localModels) return
  const updatedModels = localModels.map((model) => {
    const latestModel = latestModels.find((m) => m.modelId === model.modelId)
    if (!latestModel) return model
    return updateModelInfo(model, latestModel)
  })

  settingsStore.setState((state) => ({
    ...state,
    providers: {
      ...settings.providers,
      [providerId]: {
        ...settings.providers?.[providerId],
        models: updatedModels,
      },
    },
  }))
}

export function updateAllLocalModels() {
  getSystemProviders().forEach((provider) => {
    updateLocalModels(provider.id, provider.defaultSettings?.models ?? [])
  })
}
