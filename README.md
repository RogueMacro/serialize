# Serialize

Serialize is a generic serialization/deserialization framework for Beef.

Compile-time code generation is used for de-/serializing, so there is no need for reflection.

## Compiling

Because of a current IDE bug, in order to compile serialize, first compile with comp-time-debugging enabled. This can be found in `Build > Debug Comptime`. There will still be errors, but they won't prevent you from compiling. To make them go away, open `ISerializable.bf`.

### Supported formats

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
    Serializer<Json> serializer = scope .();

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

Some formats might have static methods for ease of use. For example (hypothetically):

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

    // Serialize to a JSON string.
    String serialized = Json.Serialize(point, .. scope String());

    // Prints {"x":1,"y":2}
    Console.WriteLine(serialized);
}
```

## Configurating the serializer

You can configure the serializer by passing a `IFormat` provider to the constructor. This is the main class of the implementation which takes care of creating specific serializers/deserializers with said config. Here is an example using TOML:

```cs
Toml config = scope .(pretty: .All); // The 'Toml' class inherits 'IFormat'
Serializer<Toml> serializer = scope .(config); // The generic argument to 'Serializer' is always a 'IFormat' type.
```

## Attributes

### `[Serializable]`

The main `[Serializable]` attribute generates an implementation of the `ISerializable` interface. Notably the `Serialize()` and `Deserialize()` methods. Can only be applied to classes and structs.

### `[Serialize]`

For serializing fields, the `[Serialize]` attribute can be used. The attribute takes a flag as the first parameter.
The flag can either be `.None` (default), `.Skip`, `.Optional` or `.Flatten`.
The default (`.None`) is that all fields are serialized, but can be skipped with the `.Skip` flag. Also, all fields are required to be present, if not marked as `.Optional`.
If you can to include unknown fields that can have any type, adding a field with the type `Dictionary<String, Variant>` and marking it with `.Flatten`, will put unknown fields into this dictionary instead.

```cs
[Serialize] // Will be serialized and is required when deserializing
public String Name ~ delete _;

[Serialize(.Skip)] // Omitted completely
public int Age;

[Serialize(.Optional)] // Can be present, or not (will be set to null)
public String FavoriteColor ~ delete _;

[Serialize(.Flatten)] // Other fields go in here
public Dictionary<String, Variant> OtherFields ~
{
    if (_ != null)
    {
        for (var (key, value) in _)
        {
            delete key;
            value.Dispose();
        }
        delete _;
    }
}
```

The `[Serialize]` attribute also has setters for renaming, default values and number formatting. For renaming you can do:

```cs
[Serialize(Rename = "Bar")] // Will be de-/serialized as 'Bar'
public int Foo;
```

For default values you have two options, either using the `Default` property, which is meant for references to functions, and will call the function you pass it, for example `Default = "CreateMyString"`, or simply `Default = "new ."`, which will compile to

```cs
if (field == null)
    field = new .();
//          ^^^^^
```

The other option is using the `DefaultValue` property. This will not append any parenthesis, so pure values/calls can be used. I.e:

```cs
[Serialize(DefaultValue = "32")]
public int Age;
```

> Note that creating these structures programmatically will not assign these default values.

Last is the `NumberFormat` property. This is used for specifying the format when serializing numbers, and is generally done through the `NumberFormatter` class, although this is format-implementation specific. For example a format like MsgPack doesn't care about how many decimals are shown, since it is stored in binary, not as a string. On the other hand, TOML or JSON might care about this.

```cs
[Serialize(NumberFormat = "F2")] // "Might" serialize two decimal places: 'Percent = 65.96'
public int Percent = 65.9635;
```
