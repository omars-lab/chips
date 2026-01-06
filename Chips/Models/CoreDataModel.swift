import CoreData

/// Programmatic Core Data model definition
/// This allows us to define the model in code rather than using .xcdatamodeld
enum CoreDataModel {
    static func createModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // ChipSource Entity
        let chipSourceEntity = NSEntityDescription()
        chipSourceEntity.name = "ChipSource"
        chipSourceEntity.managedObjectClassName = "ChipSource"

        let sourceId = NSAttributeDescription()
        sourceId.name = "id"
        sourceId.attributeType = .UUIDAttributeType
        sourceId.isOptional = true

        let sourceName = NSAttributeDescription()
        sourceName.name = "name"
        sourceName.attributeType = .stringAttributeType
        sourceName.isOptional = true

        let iCloudPath = NSAttributeDescription()
        iCloudPath.name = "iCloudPath"
        iCloudPath.attributeType = .stringAttributeType
        iCloudPath.isOptional = true

        let lastParsed = NSAttributeDescription()
        lastParsed.name = "lastParsed"
        lastParsed.attributeType = .dateAttributeType
        lastParsed.isOptional = true

        let checksum = NSAttributeDescription()
        checksum.name = "checksum"
        checksum.attributeType = .stringAttributeType
        checksum.isOptional = true

        chipSourceEntity.properties = [sourceId, sourceName, iCloudPath, lastParsed, checksum]

        // Chip Entity
        let chipEntity = NSEntityDescription()
        chipEntity.name = "Chip"
        chipEntity.managedObjectClassName = "Chip"

        let chipId = NSAttributeDescription()
        chipId.name = "id"
        chipId.attributeType = .UUIDAttributeType
        chipId.isOptional = true

        let chipTitle = NSAttributeDescription()
        chipTitle.name = "title"
        chipTitle.attributeType = .stringAttributeType
        chipTitle.isOptional = true

        let rawMarkdown = NSAttributeDescription()
        rawMarkdown.name = "rawMarkdown"
        rawMarkdown.attributeType = .stringAttributeType
        rawMarkdown.isOptional = true

        let sectionTitle = NSAttributeDescription()
        sectionTitle.name = "sectionTitle"
        sectionTitle.attributeType = .stringAttributeType
        sectionTitle.isOptional = true

        let actionType = NSAttributeDescription()
        actionType.name = "actionType"
        actionType.attributeType = .stringAttributeType
        actionType.isOptional = true

        let actionPayload = NSAttributeDescription()
        actionPayload.name = "actionPayload"
        actionPayload.attributeType = .stringAttributeType
        actionPayload.isOptional = true

        let metadata = NSAttributeDescription()
        metadata.name = "metadata"
        metadata.attributeType = .stringAttributeType
        metadata.isOptional = true

        let sortOrder = NSAttributeDescription()
        sortOrder.name = "sortOrder"
        sortOrder.attributeType = .integer32AttributeType
        sortOrder.isOptional = false
        sortOrder.defaultValue = 0

        let isCompleted = NSAttributeDescription()
        isCompleted.name = "isCompleted"
        isCompleted.attributeType = .booleanAttributeType
        isCompleted.isOptional = false
        isCompleted.defaultValue = false

        let completedAt = NSAttributeDescription()
        completedAt.name = "completedAt"
        completedAt.attributeType = .dateAttributeType
        completedAt.isOptional = true

        let createdAt = NSAttributeDescription()
        createdAt.name = "createdAt"
        createdAt.attributeType = .dateAttributeType
        createdAt.isOptional = true

        chipEntity.properties = [chipId, chipTitle, rawMarkdown, sectionTitle, actionType, actionPayload, metadata, sortOrder, isCompleted, completedAt, createdAt]

        // ChipInteraction Entity
        let interactionEntity = NSEntityDescription()
        interactionEntity.name = "ChipInteraction"
        interactionEntity.managedObjectClassName = "ChipInteraction"

        let interactionId = NSAttributeDescription()
        interactionId.name = "id"
        interactionId.attributeType = .UUIDAttributeType
        interactionId.isOptional = true

        let timestamp = NSAttributeDescription()
        timestamp.name = "timestamp"
        timestamp.attributeType = .dateAttributeType
        timestamp.isOptional = true

        let actionTaken = NSAttributeDescription()
        actionTaken.name = "actionTaken"
        actionTaken.attributeType = .stringAttributeType
        actionTaken.isOptional = true

        let duration = NSAttributeDescription()
        duration.name = "duration"
        duration.attributeType = .integer32AttributeType
        duration.isOptional = false
        duration.defaultValue = 0

        let notes = NSAttributeDescription()
        notes.name = "notes"
        notes.attributeType = .stringAttributeType
        notes.isOptional = true

        let deviceName = NSAttributeDescription()
        deviceName.name = "deviceName"
        deviceName.attributeType = .stringAttributeType
        deviceName.isOptional = true

        interactionEntity.properties = [interactionId, timestamp, actionTaken, duration, notes, deviceName]

        // Relationships
        let sourceToChips = NSRelationshipDescription()
        sourceToChips.name = "chips"
        sourceToChips.destinationEntity = chipEntity
        sourceToChips.isOptional = true
        sourceToChips.deleteRule = .cascadeDeleteRule
        sourceToChips.maxCount = 0 // To-many

        let chipToSource = NSRelationshipDescription()
        chipToSource.name = "source"
        chipToSource.destinationEntity = chipSourceEntity
        chipToSource.isOptional = true
        chipToSource.deleteRule = .nullifyDeleteRule
        chipToSource.maxCount = 1

        sourceToChips.inverseRelationship = chipToSource
        chipToSource.inverseRelationship = sourceToChips

        let chipToInteractions = NSRelationshipDescription()
        chipToInteractions.name = "interactions"
        chipToInteractions.destinationEntity = interactionEntity
        chipToInteractions.isOptional = true
        chipToInteractions.deleteRule = .cascadeDeleteRule
        chipToInteractions.maxCount = 0 // To-many

        let interactionToChip = NSRelationshipDescription()
        interactionToChip.name = "chip"
        interactionToChip.destinationEntity = chipEntity
        interactionToChip.isOptional = true
        interactionToChip.deleteRule = .nullifyDeleteRule
        interactionToChip.maxCount = 1

        chipToInteractions.inverseRelationship = interactionToChip
        interactionToChip.inverseRelationship = chipToInteractions

        // ChipActionConfiguration Entity
        let configEntity = NSEntityDescription()
        configEntity.name = "ChipActionConfiguration"
        configEntity.managedObjectClassName = "ChipActionConfiguration"

        let configId = NSAttributeDescription()
        configId.name = "id"
        configId.attributeType = .UUIDAttributeType
        configId.isOptional = true

        let configTitle = NSAttributeDescription()
        configTitle.name = "title"
        configTitle.attributeType = .stringAttributeType
        configTitle.isOptional = false

        let configSummary = NSAttributeDescription()
        configSummary.name = "summary"
        configSummary.attributeType = .stringAttributeType
        configSummary.isOptional = true

        let configDescription = NSAttributeDescription()
        configDescription.name = "configDescription"
        configDescription.attributeType = .stringAttributeType
        configDescription.isOptional = true

        let urlPattern = NSAttributeDescription()
        urlPattern.name = "urlPattern"
        urlPattern.attributeType = .stringAttributeType
        urlPattern.isOptional = true

        let configActionType = NSAttributeDescription()
        configActionType.name = "actionType"
        configActionType.attributeType = .stringAttributeType
        configActionType.isOptional = false
        configActionType.defaultValue = "url"

        let configActionURL = NSAttributeDescription()
        configActionURL.name = "actionURL"
        configActionURL.attributeType = .stringAttributeType
        configActionURL.isOptional = true

        let configXCallbackScheme = NSAttributeDescription()
        configXCallbackScheme.name = "xCallbackScheme"
        configXCallbackScheme.attributeType = .stringAttributeType
        configXCallbackScheme.isOptional = true

        let configXCallbackPath = NSAttributeDescription()
        configXCallbackPath.name = "xCallbackPath"
        configXCallbackPath.attributeType = .stringAttributeType
        configXCallbackPath.isOptional = true

        let configXCallbackParams = NSAttributeDescription()
        configXCallbackParams.name = "xCallbackParams"
        configXCallbackParams.attributeType = .stringAttributeType
        configXCallbackParams.isOptional = true

        let configTags = NSAttributeDescription()
        configTags.name = "tags"
        configTags.attributeType = .stringAttributeType
        configTags.isOptional = true

        let configIsEnabled = NSAttributeDescription()
        configIsEnabled.name = "isEnabled"
        configIsEnabled.attributeType = .booleanAttributeType
        configIsEnabled.isOptional = false
        configIsEnabled.defaultValue = true

        let configPriority = NSAttributeDescription()
        configPriority.name = "priority"
        configPriority.attributeType = .integer32AttributeType
        configPriority.isOptional = false
        configPriority.defaultValue = 0

        let configCreatedAt = NSAttributeDescription()
        configCreatedAt.name = "createdAt"
        configCreatedAt.attributeType = .dateAttributeType
        configCreatedAt.isOptional = true

        configEntity.properties = [configId, configTitle, configSummary, configDescription, urlPattern, configActionType, configActionURL, configXCallbackScheme, configXCallbackPath, configXCallbackParams, configTags, configIsEnabled, configPriority, configCreatedAt]

        // Add relationships to entities
        chipSourceEntity.properties.append(sourceToChips)
        chipEntity.properties.append(contentsOf: [chipToSource, chipToInteractions])
        interactionEntity.properties.append(interactionToChip)

        model.entities = [chipSourceEntity, chipEntity, interactionEntity, configEntity]

        return model
    }
}
