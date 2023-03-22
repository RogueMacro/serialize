# Serialize

Serialize is a generic serialization/deserialization framework for Beef.

Compile-time code generation is used for de-/serializing, so there is no need for reflection.

### Supported formats:

- [JSON](https://github.com/RogueMacro/json)
- [TOML](https://github.com/RogueMacro/toml)

## Usage

To make a type serializable, add the `[Serializable]` attribute to that type. This will automatically generate an implementation for `ISerializable`. Optionally, `ISerializable` can be implemented manually.

Here is an example using JSON:

```cs
using Serialize;

[Serializable]
struct Point
{
    public int x;
    public int y;
}

static void Main()
{
    Point point = .() { x = 1, y = 2 };

    // Create a serializer with specified format.
    Serialize<Json> serializer = scope .();

    // Serialize to a JSON string.
    String serialized = serializer.Serialize(point, .. scope String());

    // Prints {"x":1,"y":2}
    Console.WriteLine(serialized);

    // Deserialize the string back to a Point.
    Point deserialized = serializer.Deserialize<Point>(serialized);

    // Prints
    // x = 1
    // y = 2
    Console.WriteLine("x: {}", deserialized.x);
    Console.WriteLine("y: {}", deserialized.y);
}
```
