using Microsoft.ML;
using SmartParking.Application.ML;
using SmartParking.Infrastructure.Data;

public interface IParkingMlService
{
    bool Predict(int hour, int day);
}

public class ParkingMlService : IParkingMlService
{
    private readonly SmartParkingDbContext _context;
    private readonly MLContext _mlContext;
    private readonly ITransformer _model;

    public ParkingMlService(SmartParkingDbContext context)
    {
        _context = context;
        _mlContext = new MLContext();

        // Geçmiş veriyi DB’den çek
        var historyData = _context.ParkingHistories
            .Select(h => new ParkingData
            {
                HourOfDay = h.Timestamp.Hour,
                DayOfWeek = (float)h.Timestamp.DayOfWeek,
                IsAvailable = h.IsAvailable
            }).ToList();

        if (historyData.Count == 0)
        {
            historyData.AddRange(new[]
            {
                new ParkingData { HourOfDay = 8, DayOfWeek = 1, IsAvailable = true },
                new ParkingData { HourOfDay = 18, DayOfWeek = 1, IsAvailable = false }
            });
        }

        // Eğitim verisi
        var trainData = _mlContext.Data.LoadFromEnumerable(historyData);

        // Pipeline
        var pipeline = _mlContext.Transforms.Concatenate("Features", "HourOfDay", "DayOfWeek")
            .Append(_mlContext.BinaryClassification.Trainers.SdcaLogisticRegression());

        _model = pipeline.Fit(trainData);
    }

    public bool Predict(int hour, int day)
    {
        var predictionEngine = _mlContext.Model.CreatePredictionEngine<ParkingData, ParkingPrediction>(_model);
        var result = predictionEngine.Predict(new ParkingData { HourOfDay = hour, DayOfWeek = day });
        return result.WillBeAvailable;
    }
}
