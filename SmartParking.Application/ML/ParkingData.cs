using Microsoft.ML.Data;

namespace SmartParking.Application.ML;

public class ParkingData
{
    public float HourOfDay { get; set; }
    public float DayOfWeek { get; set; }
    public bool IsAvailable { get; set; }
}

public class ParkingPrediction
{
    [ColumnName("PredictedLabel")]
    public bool WillBeAvailable { get; set; }
}
