#ifdef WITH_PYTHON_ERRORS
void raiseInitializeError();
void raiseFinalizeError();
void raiseGetProductDetailsError();
void raisePerformPartitionError();
void raiseRunGenerateGraphError();
void raiseRunExecuteGraphError();
void raiseGetFreeMemoryError();
void raiseResetMaxMemoryUsedError();
void raiseGetMaxMemoryUsedError();
void raiseRunSkipDataError();
void raiseParseSchemaError();
void raiseRegisterFileSystemHDFSError();
void raiseRegisterFileSystemGCSError();
void raiseRegisterFileSystemS3Error();
void raiseRegisterFileSystemLocalError();
void raiseInferFolderPartitionMetadataError();
#endif
