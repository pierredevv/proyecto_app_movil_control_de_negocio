enum SaleDetailStatus { initial, loading, success, error }

class SaleDetailState {
  final SaleDetailStatus status;
  final String? message;

  const SaleDetailState({
    this.status = SaleDetailStatus.initial,
    this.message,
  });

  const SaleDetailState.initial()
      : status = SaleDetailStatus.initial,
        message = null;

  const SaleDetailState.loading([String? msg])
      : status = SaleDetailStatus.loading,
        message = msg;

  const SaleDetailState.success([String? msg])
      : status = SaleDetailStatus.success,
        message = msg;

  const SaleDetailState.error(String msg)
      : status = SaleDetailStatus.error,
        message = msg;

  bool get isLoading => status == SaleDetailStatus.loading;
  bool get isSuccess => status == SaleDetailStatus.success;
  bool get isError => status == SaleDetailStatus.error;
}
