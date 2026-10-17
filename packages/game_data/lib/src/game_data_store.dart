import 'dart:io';

import 'models.dart';
import 'data_pack.dart';

/// Storage contract consumed by the desktop UI. Keeping it separate from the
/// SQLite implementation allows UI tests to use an in-memory fake.
abstract interface class GameDataStore {
  Future<List<OreTraitRecord>> getOreTraits(String oreId);
  Future<DataSourceRecord?> getDataSource(String id);
  Future<ResolvedField> resolveField({
    required String entityType,
    required String entityId,
    required String fieldName,
    DataPolicy policy = DataPolicy.bestAvailable,
  });
  Future<void> addObservation(FieldObservation observation);
  Future<List<FieldObservation>> getObservations({
    required String entityType,
    required String entityId,
    required String fieldName,
  });
  Future<void> setPreferredObservation({
    required String entityType,
    required String entityId,
    required String fieldName,
    required String observationId,
  });
  Future<List<DataHealthIssue>> getDataHealthIssues();
  Future<List<OreRecord>> searchOres(
    String query, {
    DataPolicy policy = DataPolicy.bestAvailable,
  });
  Future<void> upsertDataSource(DataSourceRecord source);
  Future<void> upsertOre(OreRecord ore);
  Future<List<InventoryRecord>> getInventory({
    DataPolicy policy = DataPolicy.bestAvailable,
  });
  Future<void> setInventoryQuantity(
    String oreId,
    int quantity, {
    int protectedQuantity = 0,
  });
  Future<void> setProtectedQuantity(String oreId, int protectedQuantity);
  Future<int> countByVerificationStatus(String status);
  Future<int> countObservationsByVerificationStatus(String status);
  Future<int> countAllOres();
  Future<int> totalInventoryCount();
  Future<void> saveBuild(SavedBuildRecord build);
  Future<List<SavedBuildRecord>> getSavedBuilds();
  Future<void> deleteBuild(String id);
  Future<void> importDataPack(ValidatedDataPack pack);
  Future<String?> getActiveDataVersion();
  Future<String?> getActiveRulesetVersion();
  Future<List<WeaponClassRecord>> getWeaponClasses();
  Future<List<WeaponVariantRecord>> getWeaponVariants({String? classId});
  Future<ProbabilityTableRecord?> getProbabilityTable(String id);
  Future<void> saveCalculationSnapshot(CalculationSnapshot snapshot);
  Future<CalculationSnapshot?> getCalculationSnapshot(String id);
  Future<void> saveEvidence(EvidenceRecord evidence);
  Future<List<EvidenceRecord>> getEvidence();
  Future<EvidenceRecord?> getEvidenceByChecksum(String checksum);
  Future<List<EvidenceRecord>> getEvidenceForSession(String sessionId);
  Future<bool> isEvidenceFileIntact(EvidenceRecord evidence);
  Future<void> createVerificationSession(VerificationSession session);
  Future<RepositoryIntakeResult> importRepositoryIntake(
    RepositoryIntakeData intake, {
    required Directory evidenceDirectory,
  });
  Future<void> updateVerificationSession(VerificationSession session);
  Future<List<VerificationSession>> getVerificationSessions();
  Future<void> addVerificationTarget(VerificationTarget target);
  Future<List<VerificationTarget>> getVerificationTargets(String sessionId);
  Future<List<FieldObservation>> getVerificationQueue({String? reviewState});
  Future<List<FieldObservation>> getSessionObservations(String sessionId);
  Future<void> updateObservationReviewState(String id, String state);
  Future<void> updateEnteredObservation({
    required String id,
    required Object value,
    String? notes,
  });
  Future<void> confirmObservationCapture({
    required String observationId,
    required String evidenceId,
  });
  Future<int> confirmEvidenceCard(String evidenceId);
  Future<void> markObservationOutdated(String id);
  Future<VerifiedCandidateDiff> buildVerifiedCandidateDiff();
  Future<VerifiedCandidatePack> buildVerifiedCandidatePack();
  Future<VerificationMetrics> getVerificationMetrics();
  Future<void> confirmObservationAsInGameVerified({
    required String observationId,
    required String? gameVersion,
    required String evidenceId,
  });
  Future<void> createExperiment(ExperimentRecord experiment);
  Future<void> saveExperimentRun(
    ExperimentRunRecord run,
    List<OutcomeCount> outcomes,
  );
  Future<ExperimentSummary?> getExperimentSummary(String runId);
}
